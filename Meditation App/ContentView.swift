import SwiftUI
import AVFoundation
import UIKit

/// Theme mode options for the application
enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Sound types available in the app
enum SoundType: String, CaseIterable {
    case white = "white"
    case brown = "brown"
    case fire = "fire"
    case rain = "rain"
    case birds = "birds"
    
    var displayName: String {
        switch self {
        case .white: return "White"
        case .brown: return "Brown"
        case .fire: return "Fire"
        case .rain: return "Rain"
        case .birds: return "Birds"
        }
    }
}

/// Main view for the white noise application
struct ContentView: View {
    // MARK: - Audio Properties
    @State private var audioEngine: AVAudioEngine?
    @State private var whiteNoiseNode: AVAudioSourceNode?
    @State private var fadeTimer: Timer?
    @State private var fireAudioPlayer: AVAudioPlayer?
    @State private var brownNoiseFilter1: Float = 0.0
    @State private var fireRumble: Float = 0.0
    @State private var fireHiss: Float = 0.0
    @State private var firePop1Timer: Int = 0
    @State private var firePop1Intensity: Float = 0.0
    @State private var firePop2Timer: Int = 0
    @State private var firePop2Intensity: Float = 0.0
    @State private var fireCracklePhase: Float = 0.0
    @State private var rainDropletState: Float = 0.0
    @State private var rainSplashFilter: Float = 0.0
    @State private var rainBaseNoise: Float = 0.0
    @State private var birdCallTimer: Int = 0
    @State private var birdCallIntensity: Float = 0.0
    @State private var birdCallFilter: Float = 0.0
    @State private var frameCounter: Int = 0
    @State private var rainIntensity: Float = 0.7
    @State private var windGustPhase: Float = 0.0
    
    // MARK: - UI State
    @State private var isPlaying = false
    @State private var pulseAnimation = false
    @State private var isTransitioning = false
    @State private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    @State private var selectedSoundType: SoundType = .white
    @State private var isMenuExpanded = false
    @State private var isSoundTransitioning = false
    
    // MARK: - Environment
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ZStack {
            // Background
            backgroundColorForCurrentTheme
                .ignoresSafeArea(.all)
            
            VStack(spacing: 40) {
                // Top navigation bar with logo and theme toggle
                HStack {
                    logoView
                    Spacer()
                    themeToggleButton
                }
                .padding(.top)
                
                Spacer()
                
                // Main content
                VStack(spacing: 40) {
                    playStopButton
                }
                
                Spacer()
                
                // Bottom menu caret button
                bottomMenuButton
            }
            
            // Overlay menu
            if isMenuExpanded {
                menuOverlay
            }
        }
        .padding()
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            // Set initial theme to match system setting
            themeMode = systemColorScheme == .dark ? .dark : .light
            
            // Optimize for battery life - disable screen dimming when playing
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: isPlaying) { _, newValue in
            // Prevent screen dimming during playback for overnight use
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
    }
    
    // MARK: - UI Components
    
    /// App logo with theme-aware styling
    private var logoView: some View {
        HStack(spacing: 0) {
            Text("White")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(textColorForCurrentTheme)
            Text("noise")
                .font(.title2)
                .fontWeight(.regular)
                .foregroundColor(textColorForCurrentTheme)
        }
        .animation(.easeInOut(duration: 0.4), value: effectiveColorScheme)
    }
    
    /// Play/Stop button with pulse animation
    private var playStopButton: some View {
        Button(action: togglePlayback) {
            ZStack {
                Circle()
                    .fill(isPlaying ? playButtonStopColor : playButtonPlayColor)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: isPlaying)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .onAppear { 
            pulseAnimation = false 
        }
        .onChange(of: isPlaying) { _, newValue in
            // Smooth transition with slight delay to prevent conflicts
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseAnimation = newValue
            }
        }
    }
    
    
    // MARK: - Theme Components
    
    /// Theme toggle button with appropriate icon
    private var themeToggleButton: some View {
        Button(action: cycleThemeMode) {
            Image(systemName: themeMode.iconName)
                .font(.title2)
                .foregroundColor(textColorForCurrentTheme)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(buttonBackgroundColorForCurrentTheme)
                        .overlay(
                            Circle()
                                .stroke(textColorForCurrentTheme.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .opacity(themeButtonOpacity)
        .animation(.easeInOut(duration: 0.3), value: themeButtonOpacity)
        .animation(.easeInOut(duration: 0.4), value: effectiveColorScheme)
        .accessibilityLabel("Theme: \(themeMode.displayName)")
        .accessibilityHint("Double tap to switch between light and dark themes")
        .onTapGesture {
            // Briefly brighten on tap
            withAnimation(.easeInOut(duration: 0.1)) {
                themeButtonOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    themeButtonOpacity = 0.6
                }
            }
        }
    }
    
    // MARK: - Theme Management
    
    /// Returns the appropriate ColorScheme based on current theme mode
    private var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    /// Returns the current effective color scheme
    private var effectiveColorScheme: ColorScheme {
        switch themeMode {
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    /// Background color based on current theme
    private var backgroundColorForCurrentTheme: Color {
        effectiveColorScheme == .dark ? .black : .white
    }
    
    /// Text color with WCAG-compliant contrast
    private var textColorForCurrentTheme: Color {
        effectiveColorScheme == .dark ? .white : .black
    }
    
    /// Button background color for theme toggle
    private var buttonBackgroundColorForCurrentTheme: Color {
        effectiveColorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    /// Play button color with WCAG-compliant contrast
    private var playButtonPlayColor: Color {
        effectiveColorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
    }
    
    /// Stop button color with WCAG-compliant contrast  
    private var playButtonStopColor: Color {
        effectiveColorScheme == .dark ? Color.red.opacity(0.8) : Color.red
    }
    
    
    /// Liquid Glass background for menu overlay following Apple's design language
    private var liquidGlassBackground: some View {
        // Base translucent layer with ultraThinMaterial
        if effectiveColorScheme == .dark {
            // Dark mode: lighter silver translucent
            Color.white.opacity(0.08)
                .background(.ultraThinMaterial)
        } else {
            // Light mode: mid to dark grey translucent
            Color.black.opacity(0.05)
                .background(.ultraThinMaterial)
        }
    }
    
    /// Menu handle color with proper contrast
    private var menuHandleColor: Color {
        effectiveColorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.3)
    }
    
    
    /// Bottom menu button with up caret
    private var bottomMenuButton: some View {
        Button(action: toggleMenu) {
            Image(systemName: "chevron.up")
                .font(.title2)
                .foregroundColor(textColorForCurrentTheme.opacity(0.7))
                .rotationEffect(.degrees(isMenuExpanded ? 180 : 0))
                .animation(.easeInOut(duration: 0.3), value: isMenuExpanded)
        }
        .padding(.bottom, 20)
    }
    
    /// Overlay menu that slides up from bottom as unified element
    private var menuOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Unified sliding overlay - fixed height, extends to bottom
            VStack(spacing: 0) {
                // Up caret at top of overlay
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isMenuExpanded = false
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.title2)
                            .foregroundColor(menuHandleColor)
                            .rotationEffect(.degrees(180)) // Point down to indicate close
                    }
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                // Sound selector - all sounds on equal footing
                HStack {
                    soundButton(.white)
                    Spacer()
                    soundButton(.brown)
                    Spacer()
                    soundButton(.fire)
                    Spacer()
                    soundButton(.rain)
                    Spacer()
                    soundButton(.birds)
                }
                .padding(.horizontal, 24)
                
                // Fill remaining space to bottom of screen
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                liquidGlassBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -8)
            .ignoresSafeArea(.container, edges: .horizontal)
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuExpanded)
    }
    
    /// Sound button - only one can be selected at a time
    private func soundButton(_ type: SoundType) -> some View {
        Button(action: { selectSound(type) }) {
            ZStack {
                Circle()
                    .fill(selectedSoundType == type ? soundBackgroundColor(for: type) : buttonBackgroundColorForCurrentTheme)
                    .frame(width: 44, height: 44)
                
                Text(iconForSound(type))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(selectedSoundType == type ? .white : textColorForCurrentTheme)
            }
        }
        .accessibilityLabel("\(type.displayName) sound")
        .accessibilityHint("Select \(type.displayName.lowercased()) sound")
    }
    
    /// Icon for sounds
    private func iconForSound(_ sound: SoundType) -> String {
        switch sound {
        case .white: return "W"
        case .brown: return "B"
        case .fire: return "🔥"
        case .rain: return "🌧️"
        case .birds: return "🐦"
        }
    }
    
    /// Background color for sound buttons
    private func soundBackgroundColor(for sound: SoundType) -> Color {
        switch sound {
        case .white: return .gray
        case .brown: return .brown
        case .fire: return .red
        case .rain: return .blue
        case .birds: return .green
        }
    }

    // MARK: - Audio Control
    
    /// Toggles between play and stop states with debouncing
    private func togglePlayback() {
        guard !isTransitioning else { return }
        
        // Provide haptic feedback for physical button feel
        triggerHapticFeedback()
        
        isTransitioning = true
        
        if isPlaying {
            stopWhiteNoise()
        } else {
            playWhiteNoise()
        }
    }
    
    /// Starts white noise generation with audio processing chain
    private func playWhiteNoise() {
        // Configure audio session for media playback (works in silent mode)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration error: \(error.localizedDescription)")
        }
        
        // Handle fire sound with audio file
        if selectedSoundType == .fire {
            playFireAudio()
            return
        }
        
        // Handle other sounds with audio engine
        let engine = AVAudioEngine()
        let noiseNode = createWhiteNoiseNode()
        let lowPassFilter = createLowPassFilter()
        
        setupAudioChain(engine: engine, noiseNode: noiseNode, filter: lowPassFilter)
        
        do {
            try engine.start()
            audioEngine = engine
            whiteNoiseNode = noiseNode
            
            // Set playing state immediately for smooth UI feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                isPlaying = true
            }
            
            fadeIn(engine.mainMixerNode) {
                self.isTransitioning = false
                self.isSoundTransitioning = false
            }
        } catch {
            print("Audio engine error: \(error.localizedDescription)")
            isPlaying = false
            isTransitioning = false
            isSoundTransitioning = false
        }
    }
    
    /// Plays fire audio using AVAudioPlayer with mp3 file
    private func playFireAudio() {
        guard let path = Bundle.main.path(forResource: "fire", ofType: "mp3") else {
            print("Could not find fire.mp3 in bundle")
            isPlaying = false
            isTransitioning = false
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            fireAudioPlayer = try AVAudioPlayer(contentsOf: url)
            fireAudioPlayer?.numberOfLoops = -1 // Infinite loop
            fireAudioPlayer?.volume = 0.8
            fireAudioPlayer?.play()
            
            // Set playing state immediately for smooth UI feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                isPlaying = true
            }
            
            isTransitioning = false
        } catch {
            print("Fire audio player error: \(error.localizedDescription)")
            isPlaying = false
            isTransitioning = false
            isSoundTransitioning = false
        }
    }
    
    /// Creates audio source node for noise generation based on current type
    private func createWhiteNoiseNode() -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for buffer in bufferListPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                
                // Single sound - consistent gain level
                let finalGain: Float = 0.8
                
                for frame in 0..<Int(frameCount) {
                    var output: Float = 0.0
                    self.frameCounter += 1
                    
                    // Generate sound based on selected type - single sound only
                    // Note: Fire sound is handled separately with AVAudioPlayer
                    switch self.selectedSoundType {
                    case .white:
                        output = Float.random(in: -0.5...0.5)
                    case .brown:
                        let whiteNoise = Float.random(in: -0.3...0.3)
                        self.brownNoiseFilter1 += 0.1 * (whiteNoise - self.brownNoiseFilter1)
                        output = self.brownNoiseFilter1 * 1.5
                    case .fire:
                        // Fire sound is handled by AVAudioPlayer - this should not be called
                        output = 0.0
                    case .rain:
                        // Improved realistic rainfall with multiple rain intensities
                        
                        // Base rain hiss - steady rainfall on surfaces
                        let baseRainNoise = Float.random(in: -0.5...0.5)
                        self.rainBaseNoise += 0.08 * (baseRainNoise - self.rainBaseNoise)
                        
                        // Varying rain intensity with natural fluctuation
                        if self.frameCounter % 200 == 0 {
                            let intensityChange = Float.random(in: -0.1...0.1)
                            self.rainIntensity = max(0.3, min(1.0, self.rainIntensity + intensityChange))
                        }
                        
                        // Individual heavy droplets - size varies
                        var dropletNoise: Float = 0.0
                        if arc4random_uniform(25) == 0 { // More frequent drops
                            let dropSize = Float.random(in: 0.2...0.8)
                            dropletNoise = Float.random(in: -0.7...0.7) * dropSize
                        }
                        
                        // Droplet splash/reverb with realistic decay
                        self.rainSplashFilter += 0.3 * (dropletNoise - self.rainSplashFilter)
                        
                        // Distant thunder rumble - occasional
                        var thunderRumble: Float = 0.0
                        if self.frameCounter % 300 == 0 {
                            let distantNoise = Float.random(in: -0.08...0.08)
                            self.rainDropletState += 0.01 * (distantNoise - self.rainDropletState)
                        }
                        if arc4random_uniform(8000) == 0 { // Very rare distant thunder
                            thunderRumble = Float.random(in: -0.15...0.15)
                        }
                        
                        // Rain on leaves/surfaces - higher frequency patter
                        var leafRain: Float = 0.0
                        if arc4random_uniform(15) == 0 {
                            leafRain = Float.random(in: -0.3...0.3) * 0.4
                        }
                        
                        output = (self.rainBaseNoise * self.rainIntensity * 0.9) + // Base rain
                                (dropletNoise * 0.4) + // Individual drops
                                (self.rainSplashFilter * 0.3) + // Splash reverb
                                (self.rainDropletState * 0.6) + // Distant rumble
                                (thunderRumble * 0.5) + // Rare thunder
                                leafRain // Surface patter
                    case .birds:
                        // Improved forest birds with variety and realism
                        
                        // Primary bird call - melodic with natural variation
                        var primaryCall: Float = 0.0
                        if self.birdCallTimer > 0 {
                            let callProgress = Float(self.birdCallTimer) * 0.002 // Slower progression
                            let melody1 = sin(callProgress * 20.0) * 0.4 // Primary melody
                            let melody2 = sin(callProgress * 35.0) * 0.2 // Harmonic
                            let warble = sin(callProgress * 8.0) * 0.1 // Natural warble
                            primaryCall = self.birdCallIntensity * (melody1 + melody2 + warble)
                            self.birdCallTimer -= 1
                        } else if self.frameCounter % 800 == 0 && arc4random_uniform(12) == 0 {
                            self.birdCallTimer = Int.random(in: 300...1200) // Longer, more varied calls
                            self.birdCallIntensity = Float.random(in: 0.15...0.4)
                        }
                        
                        // Multiple bird species - different call patterns
                        var distantCall: Float = 0.0
                        if arc4random_uniform(1200) == 0 { // Less frequent distant birds
                            let pitch = Float.random(in: 0.3...0.8)
                            distantCall = pitch * 0.2
                        }
                        
                        // Quick chirps and tweets
                        var quickChirp: Float = 0.0
                        if arc4random_uniform(150) == 0 {
                            quickChirp = Float.random(in: -0.3...0.3) * Float.random(in: 0.2...0.5)
                        }
                        
                        // Wing flutter and movement sounds
                        var wingSound: Float = 0.0
                        if arc4random_uniform(2000) == 0 {
                            wingSound = Float.random(in: -0.15...0.15) * 0.3
                        }
                        
                        // Subtle background forest ambience
                        var forestAmbient: Float = 0.0
                        if self.frameCounter % 100 == 0 {
                            let ambientNoise = Float.random(in: -0.05...0.05)
                            self.windGustPhase += 0.02 * (ambientNoise - self.windGustPhase)
                        }
                        forestAmbient = self.windGustPhase
                        
                        // Apply natural filtering to main call
                        self.birdCallFilter += 0.25 * (primaryCall - self.birdCallFilter)
                        
                        output = self.birdCallFilter + // Primary filtered call
                                distantCall + // Distant birds
                                quickChirp + // Quick chirps
                                wingSound + // Wing movements
                                (forestAmbient * 0.8) // Forest ambience
                    }
                    
                    // Efficient clamping and final output
                    data[frame] = max(-0.9, min(0.9, output)) * finalGain
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
        // Set stopped state immediately for smooth UI feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = false
        }
        
        // Stop fire audio player if it's playing
        if let firePlayer = fireAudioPlayer {
            firePlayer.stop()
            fireAudioPlayer = nil
            isTransitioning = false
            
            // Deactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Audio session deactivation error: \(error.localizedDescription)")
            }
            return
        }
        
        // Stop audio engine for other sounds
        guard let engine = audioEngine else { 
            isTransitioning = false
            return 
        }
        
        fadeOut(engine.mainMixerNode) {
            engine.stop()
            audioEngine = nil
            whiteNoiseNode = nil
            isTransitioning = false
            
            // Deactivate audio session when stopping to save battery
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Audio session deactivation error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Fading
    
    /// Gradually increases volume from 0 to system volume
    private func fadeIn(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        performFade(mixerNode: mixerNode, duration: duration, startVolume: 0.0, endVolume: 1.0, completion: completion)
    }

    /// Gradually decreases volume to 0 then executes completion
    private func fadeOut(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 0.1, completion: @escaping () -> Void) {
        let currentVolume = mixerNode.outputVolume
        performFade(mixerNode: mixerNode, duration: duration, startVolume: currentVolume, endVolume: 0.0, completion: completion)
    }
    
    /// Core fade implementation with configurable start/end volumes
    private func performFade(mixerNode: AVAudioMixerNode, duration: TimeInterval, startVolume: Float, endVolume: Float, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        
        // Capture current volume before any changes to ensure smooth transition
        let actualStartVolume = mixerNode.outputVolume
        
        // If we're very close to the target, just set it directly to avoid micro-fades
        if abs(actualStartVolume - endVolume) < 0.01 {
            mixerNode.outputVolume = endVolume
            completion?()
            return
        }
        
        let fadeSteps = 50
        let stepDuration = duration / Double(fadeSteps)
        let volumeDelta = (endVolume - actualStartVolume) / Float(fadeSteps)
        
        // Don't immediately set volume - use current volume as true starting point
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            mixerNode.outputVolume += volumeDelta
            
            // Clamp volume to valid range to prevent audio artifacts
            mixerNode.outputVolume = max(0.0, min(1.0, mixerNode.outputVolume))
            
            let isComplete = volumeDelta > 0 ? mixerNode.outputVolume >= endVolume : mixerNode.outputVolume <= endVolume
            
            if isComplete {
                mixerNode.outputVolume = endVolume
                timer.invalidate()
                completion?()
            }
        }
    }

    
    // MARK: - Theme Actions
    
    /// Toggles between light and dark theme modes
    private func cycleThemeMode() {
        triggerLightHapticFeedback()
        
        switch themeMode {
        case .light:
            themeMode = .dark
        case .dark:
            themeMode = .light
        }
    }
    
    // MARK: - Menu Actions
    
    /// Toggles the bottom menu visibility
    private func toggleMenu() {
        triggerLightHapticFeedback()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isMenuExpanded.toggle()
        }
    }
    
    /// Selects sound type - only one at a time with debouncing
    private func selectSound(_ type: SoundType) {
        // Prevent rapid button mashing
        guard selectedSoundType != type && !isSoundTransitioning else { return }
        
        triggerLightHapticFeedback()
        
        // Set transitioning flag immediately
        isSoundTransitioning = true
        selectedSoundType = type
        
        // If audio is playing, restart with new sound
        if isPlaying {
            restartAudioWithCurrentSettings()
        } else {
            // Reset transitioning flag immediately if not playing
            isSoundTransitioning = false
        }
    }
    
    /// Restarts audio with current sound settings
    private func restartAudioWithCurrentSettings() {
        // Check if we're currently using fire audio player
        let wasUsingFireAudio = (fireAudioPlayer != nil)
        let willUseFireAudio = (selectedSoundType == .fire)
        
        // For same audio system (generated to generated), just reset state
        if !wasUsingFireAudio && !willUseFireAudio {
            // Reset all filter states immediately for clean transition
            brownNoiseFilter1 = 0.0
            rainDropletState = 0.0
            rainSplashFilter = 0.0
            rainBaseNoise = 0.0
            birdCallTimer = 0
            birdCallIntensity = 0.0
            birdCallFilter = 0.0
            frameCounter = 0
            rainIntensity = 0.7
            windGustPhase = 0.0
            
            // Clear transition flag immediately for generated sounds
            isSoundTransitioning = false
            return
        }
        
        // For switching between audio systems (generated ↔ fire MP3)
        stopWhiteNoise()
        
        // Minimal delay for fire sound transitions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.playWhiteNoise()
            // Clear transition flag after restart
            self.isSoundTransitioning = false
        }
    }
    
    // MARK: - Haptic Feedback
    
    /// Triggers haptic feedback to simulate physical button press
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Triggers lighter haptic feedback for secondary actions like theme switching
    private func triggerLightHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
