import SwiftUI
import AVFoundation

/// Main view for the white noise application
struct ContentView: View {
    // MARK: - Audio Properties
    @State private var audioEngine: AVAudioEngine?
    @State private var whiteNoiseNode: AVAudioSourceNode?
    @State private var fadeTimer: Timer?
    
    // MARK: - UI State
    @State private var isPlaying = false
    @State private var pulseAnimation = false
    @State private var volume: Float = 1.0

    var body: some View {
        VStack(spacing: 40) {
            playStopButton
            volumeSlider
        }
        .padding()
    }
    
    // MARK: - UI Components
    
    /// Play/Stop button with pulse animation
    private var playStopButton: some View {
        Button(action: togglePlayback) {
            ZStack {
                Circle()
                    .fill(isPlaying ? .red : .blue)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(
                        pulseAnimation ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                        value: pulseAnimation
                    )
                
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
        }
        .onAppear { pulseAnimation = false }
        .onChange(of: isPlaying) { pulseAnimation = $0 }
    }
    
    /// Volume control slider
    private var volumeSlider: some View {
        Slider(value: volumeBinding, in: 0.0...1.0)
            .frame(width: 200)
    }
    
    /// Binding for volume slider with automatic audio update
    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(volume) },
            set: { newValue in
                volume = Float(newValue)
                updateVolume()
            }
        )
    }

    // MARK: - Audio Control
    
    /// Toggles between play and stop states
    private func togglePlayback() {
        isPlaying ? stopWhiteNoise() : playWhiteNoise()
    }
    
    /// Starts white noise generation with audio processing chain
    private func playWhiteNoise() {
        let engine = AVAudioEngine()
        let noiseNode = createWhiteNoiseNode()
        let lowPassFilter = createLowPassFilter()
        
        setupAudioChain(engine: engine, noiseNode: noiseNode, filter: lowPassFilter)
        
        do {
            try engine.start()
            audioEngine = engine
            whiteNoiseNode = noiseNode
            fadeIn(engine.mainMixerNode)
            isPlaying = true
        } catch {
            print("Audio engine error: \(error.localizedDescription)")
        }
    }
    
    /// Creates audio source node for white noise generation
    private func createWhiteNoiseNode() -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for buffer in bufferListPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                
                for frame in 0..<Int(frameCount) {
                    data[frame] = Float.random(in: -0.5...0.5)
                }
            }
            return noErr
        }
    }
    
    /// Creates low-pass filter to reduce harsh frequencies
    private func createLowPassFilter() -> AVAudioUnitEQ {
        let filter = AVAudioUnitEQ(numberOfBands: 1)
        filter.bands[0].filterType = .lowPass
        filter.bands[0].frequency = 1000
        filter.bands[0].bypass = false
        return filter
    }
    
    /// Sets up the audio processing chain
    private func setupAudioChain(engine: AVAudioEngine, noiseNode: AVAudioSourceNode, filter: AVAudioUnitEQ) {
        engine.attach(noiseNode)
        engine.attach(filter)
        engine.connect(noiseNode, to: filter, format: nil)
        engine.connect(filter, to: engine.mainMixerNode, format: nil)
    }

    /// Stops white noise with fade-out effect
    private func stopWhiteNoise() {
        guard let engine = audioEngine else { return }
        
        fadeOut(engine.mainMixerNode) {
            engine.stop()
            audioEngine = nil
            whiteNoiseNode = nil
            isPlaying = false
        }
    }

    // MARK: - Audio Fading
    
    /// Gradually increases volume from 0 to current volume setting
    private func fadeIn(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 2.0) {
        performFade(mixerNode: mixerNode, duration: duration, startVolume: 0.0, endVolume: volume)
    }

    /// Gradually decreases volume to 0 then executes completion
    private func fadeOut(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 0.5, completion: @escaping () -> Void) {
        performFade(mixerNode: mixerNode, duration: duration, startVolume: mixerNode.outputVolume, endVolume: 0.0, completion: completion)
    }
    
    /// Core fade implementation with configurable start/end volumes
    private func performFade(mixerNode: AVAudioMixerNode, duration: TimeInterval, startVolume: Float, endVolume: Float, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        
        let fadeSteps = 50
        let stepDuration = duration / Double(fadeSteps)
        let volumeDelta = (endVolume - startVolume) / Float(fadeSteps)
        
        mixerNode.outputVolume = startVolume
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            mixerNode.outputVolume += volumeDelta
            
            let isComplete = volumeDelta > 0 ? mixerNode.outputVolume >= endVolume : mixerNode.outputVolume <= endVolume
            
            if isComplete {
                mixerNode.outputVolume = endVolume
                timer.invalidate()
                completion?()
            }
        }
    }

    /// Updates the audio engine volume to match current volume setting
    private func updateVolume() {
        audioEngine?.mainMixerNode.outputVolume = volume
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
