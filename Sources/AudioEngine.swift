//
//  AudioEngine.swift
//  No-BS White Noise
//
//  Owns all audio: playback, generation, fades, volume, the sleep timer,
//  Now Playing metadata, remote commands, Siri intents, and interruptions.
//  ContentView is pure presentation on top of this class.
//
//  Render-thread safety: the AVAudioSourceNode render closure never touches
//  observable state. The selected sound crosses the thread boundary through
//  an OSAllocatedUnfairLock box; the brown-noise filter lives in a mutable
//  var captured by the closure and is only ever touched on the render thread.
//

import AVFoundation
import MediaPlayer
import Observation
import UIKit
import os

@Observable
@MainActor
final class AudioEngine {

    // MARK: - Observable state (drives the UI)

    private(set) var isPlaying = false
    private(set) var isTransitioning = false
    private(set) var sleepTimerEndDate: Date?
    private(set) var sleepTimerMinutes: Int?

    var selectedSound: SoundType {
        didSet {
            UserDefaults.standard.set(selectedSound.rawValue, forKey: "selectedSound")
            let newValue = selectedSound
            renderSound.withLock { $0 = newValue }
        }
    }

    var masterVolume: Double {
        didSet {
            UserDefaults.standard.set(masterVolume, forKey: "masterVolume")
            applyMasterVolume()
        }
    }

    /// Sleep timer choices, in minutes.
    static let sleepTimerOptions: [Int] = [15, 30, 45, 60, 90, 120]

    // MARK: - Private audio machinery

    private var avEngine: AVAudioEngine?
    private var noiseNode: AVAudioSourceNode?
    private var currentAudioPlayer: AVAudioPlayer?
    private var preloadedPlayers: [SoundType: AVAudioPlayer] = [:]
    private var audioTask: Task<Void, Never>?
    private var sleepTimerTask: Task<Void, Never>?

    /// The sound the render thread should generate — lock-boxed for cross-thread reads.
    private let renderSound = OSAllocatedUnfairLock(initialState: SoundType.white)

    private let fadeInDuration: TimeInterval = 0.5

    // MARK: - Init / start

    private var hasStarted = false

    init() {
        let defaults = UserDefaults.standard
        let sound = SoundType(rawValue: defaults.string(forKey: "selectedSound") ?? "") ?? .white
        selectedSound = sound
        masterVolume = defaults.object(forKey: "masterVolume") as? Double ?? 0.7
        renderSound.withLock { $0 = sound }
    }

    /// One-time side-effectful setup (preload, remote commands, observers).
    /// Called from the view's onAppear — kept out of init because SwiftUI may
    /// evaluate @State initializers for transient, discarded instances.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        preloadAudioFiles()
        setupRemoteCommandCenter()
        setupSiriIntentListener()
        observeInterruptions()
    }

    // MARK: - Playback control

    /// Toggles play/stop with an optimistic state flip. Returns the new target state.
    @discardableResult
    func togglePlayback() -> Bool {
        guard !isTransitioning else { return isPlaying }
        isTransitioning = true

        let targetState = !isPlaying
        isPlaying = targetState

        // Manual stop also clears any armed sleep timer
        if !targetState {
            cancelSleepTimer()
        }

        audioTask?.cancel()
        audioTask = Task { @MainActor in
            if targetState {
                await startAudio()
            } else {
                await fadeCurrentAudio(to: 0, duration: 0.3)
                await stopAudioSilently()
            }
            isTransitioning = false
        }
        return targetState
    }

    /// Selects a sound; if playing, restarts playback with the new sound.
    func selectSound(_ type: SoundType) {
        guard selectedSound != type else { return }
        selectedSound = type
        updateNowPlayingInfo()

        if isPlaying {
            audioTask?.cancel()
            audioTask = Task { @MainActor in
                await stopAudioSilently()
                await startAudio()
            }
        }
    }

    /// Cycles to the next sound in the list
    func cycleToNextSound() {
        let all = SoundType.allCases
        guard let index = all.firstIndex(of: selectedSound) else { return }
        selectSound(all[(index + 1) % all.count])
    }

    /// Cycles to the previous sound in the list
    func cycleToPreviousSound() {
        let all = SoundType.allCases
        guard let index = all.firstIndex(of: selectedSound) else { return }
        selectSound(all[(index - 1 + all.count) % all.count])
    }

    // MARK: - Sleep timer

    /// Arms the sleep timer for the given minutes, or cancels it when `nil` ("Off").
    func setSleepTimer(_ minutes: Int?) {
        guard let minutes else {
            cancelSleepTimer()
            return
        }

        sleepTimerTask?.cancel()
        sleepTimerMinutes = minutes
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))

        sleepTimerTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(minutes * 60))
            } catch {
                return // cancelled — re-armed, turned off, or manual stop
            }
            guard !Task.isCancelled else { return }
            await fadeOutAndStop()
        }
    }

    /// Cancels the sleep timer without touching playback.
    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndDate = nil
        sleepTimerMinutes = nil
    }

    // MARK: - Lifecycle

    /// Comprehensive cleanup of all audio resources
    func cleanup() {
        audioTask?.cancel()
        cancelSleepTimer()

        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        avEngine?.stop()
        avEngine = nil
        noiseNode = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Audio session deactivation error: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    /// Screenshot support: force UI-visible state without starting real audio.
    func applyScreenshotState(playing: Bool?, timerMinutes: Int?) {
        if let playing { isPlaying = playing }
        if let timerMinutes {
            sleepTimerMinutes = timerMinutes
            sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(timerMinutes * 60))
        }
    }
    #endif

    // MARK: - Audio startup

    private func startAudio() async {
        do {
            // Configure audio session for Now Playing / Control Center visibility
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            if let player = preloadedPlayers[selectedSound] {
                await playMPAudio(player: player)
            } else {
                try await playGeneratedAudio()
            }
            updateNowPlayingInfo()
        } catch {
            print("Audio start error: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// Plays MP3 audio using a preloaded AVAudioPlayer, fading in gently
    private func playMPAudio(player: AVAudioPlayer) async {
        await stopAudioSilently()

        player.volume = 0
        currentAudioPlayer = player
        player.numberOfLoops = -1
        player.currentTime = 0
        player.play()
        player.setVolume(effectiveMP3Volume, fadeDuration: fadeInDuration)
    }

    /// Plays generated audio using AVAudioEngine, fading in gently
    private func playGeneratedAudio() async throws {
        await stopAudioSilently()

        let engine = AVAudioEngine()
        let node = makeNoiseSourceNode()
        let filter = makeLowPassFilter()

        engine.attach(node)
        engine.attach(filter)
        engine.connect(node, to: filter, format: nil)
        engine.connect(filter, to: engine.mainMixerNode, format: nil)

        engine.mainMixerNode.outputVolume = 0
        try engine.start()
        avEngine = engine
        noiseNode = node
        await fadeCurrentAudio(to: Float(masterVolume), duration: fadeInDuration)
    }

    private func stopAudioSilently() async {
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        avEngine?.stop()
        avEngine = nil
        noiseNode = nil
    }

    // MARK: - Volume & fades

    /// The MP3 player volume for the current sound and master volume setting.
    private var effectiveMP3Volume: Float {
        Self.mp3BaseVolume(for: selectedSound) * Float(masterVolume)
    }

    /// Per-sound base gain, tuned from measured file RMS (fire 0.025, rain 0.045,
    /// birds 0.008) with √-compression, anchored to rain ≈ the previous 0.3 level.
    static func mp3BaseVolume(for type: SoundType) -> Float {
        switch type {
        case .fire: return 0.60
        case .rain: return 0.45
        case .birds: return 1.0
        default: return 0.45 // white/brown are engine-generated; not used
        }
    }

    /// Fades whatever is currently playing to `target` volume over `duration`.
    private func fadeCurrentAudio(to target: Float, duration: TimeInterval) async {
        if let player = currentAudioPlayer {
            player.setVolume(target, fadeDuration: duration)
            try? await Task.sleep(for: .seconds(duration + 0.05))
        } else if let engine = avEngine {
            let steps = max(6, Int(duration / 0.05))
            let start = engine.mainMixerNode.outputVolume
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(steps)
                engine.mainMixerNode.outputVolume = start + (target - start) * progress
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
            }
        }
    }

    /// Applies the master volume to whatever is currently playing (live, no fade).
    private func applyMasterVolume() {
        currentAudioPlayer?.volume = effectiveMP3Volume
        avEngine?.mainMixerNode.outputVolume = Float(masterVolume)
    }

    /// Gently fades to silence over ~3s, then stops (sleep-timer expiry path).
    private func fadeOutAndStop() async {
        await fadeCurrentAudio(to: 0, duration: 3.0)
        await stopAudioSilently()
        isPlaying = false
        cancelSleepTimer()
        updateNowPlayingInfo()
    }

    // MARK: - Noise generation (render thread)

    /// Builds the source node. The render closure reads the selected sound through
    /// a lock box and owns its brown-noise filter privately — no view/observable
    /// state is ever touched on the audio thread.
    private func makeNoiseSourceNode() -> AVAudioSourceNode {
        let soundBox = renderSound
        // Render-thread-private filter state; seeded here, then only the render
        // thread reads/writes it via the closure capture.
        var brownFilter = Float.random(in: -0.05...0.05)

        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let soundType = soundBox.withLock { $0 }

            for buffer in bufferListPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }

                let finalGain: Float = 0.8
                let frameCountInt = Int(frameCount)

                switch soundType {
                case .white:
                    var rng = SystemRandomNumberGenerator()
                    for frame in 0..<frameCountInt {
                        let randomValue = Float(rng.next()) / Float(UInt64.max) // 0 to 1
                        data[frame] = (randomValue * 0.8 - 0.4) * finalGain
                    }

                case .brown:
                    let filterCoeff: Float = 0.02
                    let gainComp: Float = 3.5
                    var filter = brownFilter
                    var rng = SystemRandomNumberGenerator()

                    for frame in 0..<frameCountInt {
                        let randomValue = Float(rng.next()) / Float(UInt64.max)
                        let noise = randomValue * 0.6 - 0.3
                        filter += filterCoeff * (noise - filter)
                        let sample = filter * gainComp
                        data[frame] = (sample < -1.0 ? -1.0 : (sample > 1.0 ? 1.0 : sample)) * finalGain
                    }

                    brownFilter = filter

                default:
                    memset(data, 0, frameCountInt * MemoryLayout<Float>.stride)
                }
            }
            return noErr
        }
    }

    /// Low-pass filter tuned per sound to soften harsh frequencies
    private func makeLowPassFilter() -> AVAudioUnitEQ {
        let filter = AVAudioUnitEQ(numberOfBands: 1)
        filter.bands[0].filterType = .lowPass
        switch selectedSound {
        case .white: filter.bands[0].frequency = 8000
        case .brown: filter.bands[0].frequency = 4000
        default: filter.bands[0].frequency = 6000
        }
        filter.bands[0].bypass = false
        return filter
    }

    // MARK: - Preloading

    /// Preloads MP3 players; playback volume is applied at play time.
    private func preloadAudioFiles() {
        let audioFiles: [(SoundType, String)] = [
            (.fire, "fire"),
            (.rain, "rain"),
            (.birds, "birdsounds")
        ]

        for (soundType, filename) in audioFiles {
            guard let path = Bundle.main.path(forResource: filename, ofType: "mp3") else {
                print("Audio file not found: \(filename).mp3")
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                player.prepareToPlay()
                player.enableRate = false
                preloadedPlayers[soundType] = player
            } catch {
                print("Failed to preload \(filename) audio: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Remote control / Now Playing

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if let self, !self.isPlaying { self.togglePlayback() }
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if let self, self.isPlaying { self.togglePlayback() }
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.cycleToNextSound() }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.cycleToPreviousSound() }
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }

    /// Updates Now Playing info for Control Center and the Lock Screen
    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(selectedSound.displayName) Noise"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "No-BS White Noise"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let logoImage = UIImage(named: "logo") {
            let artwork = MPMediaItemArtwork(boundsSize: logoImage.size) { _ in logoImage }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Siri / interruptions

    private func setupSiriIntentListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlaySoundFromSiri"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let soundTypeString = userInfo["soundType"] as? String else { return }

            let soundType: SoundType
            switch soundTypeString.lowercased() {
            case "white noise", "white": soundType = .white
            case "brown noise", "brown": soundType = .brown
            case "fire": soundType = .fire
            case "rain": soundType = .rain
            case "birds", "bird sounds": soundType = .birds
            default: return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.selectSound(soundType)
                if !self.isPlaying {
                    self.togglePlayback()
                }
            }
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .began else { return }

            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.isPlaying = false
                // Playback ended, so the armed timer no longer has anything to stop
                self.cancelSleepTimer()
                self.updateNowPlayingInfo()
            }
        }
    }
}
