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

/// Base noise type (required - white or brown)
enum BaseNoiseType: String, CaseIterable {
    case white = "white"
    case brown = "brown"
    
    var displayName: String {
        switch self {
        case .white: return "White"
        case .brown: return "Brown"
        }
    }
}

/// Ambient sound mix-ins (optional add-ons)
enum AmbientSound: String, CaseIterable {
    case fire = "fire"
    case rain = "rain"
    case birds = "birds"
    
    var displayName: String {
        switch self {
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
    
    // MARK: - UI State
    @State private var isPlaying = false
    @State private var pulseAnimation = false
    @State private var isTransitioning = false
    @State private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    @State private var baseNoiseType: BaseNoiseType = .white
    @State private var activeAmbientSounds: Set<AmbientSound> = []
    @State private var isMenuExpanded = false
    
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
        ZStack {
            // Base translucent layer
            if effectiveColorScheme == .dark {
                // Dark mode: lighter silver translucent
                Color.white.opacity(0.08)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                // Light mode: mid to dark grey translucent
                Color.black.opacity(0.05)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
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
                
                // Sound selector
                HStack {
                    // Base noise types (left side - OR logic)
                    baseNoiseButton(.white)
                    Spacer()
                    baseNoiseButton(.brown)
                    
                    // Vertical separator line
                    Spacer()
                    Rectangle()
                        .fill(menuHandleColor)
                        .frame(width: 1, height: 30)
                    Spacer()
                    
                    // Ambient sounds (right side - ADD logic)
                    ambientSoundButton(.fire)
                    Spacer()
                    ambientSoundButton(.rain)
                    Spacer()
                    ambientSoundButton(.birds)
                }
                .padding(.horizontal, 24)
                
                // Fill remaining space to bottom of screen
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                liquidGlassBackground
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -8)
            )
            .clipped()
            .ignoresSafeArea(.all, edges: [.horizontal, .bottom])
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuExpanded)
    }
    
    /// Base noise type button (OR logic - only one can be selected)
    private func baseNoiseButton(_ type: BaseNoiseType) -> some View {
        Button(action: { selectBaseNoise(type) }) {
            ZStack {
                Circle()
                    .fill(baseNoiseType == type ? baseNoiseBackgroundColor(for: type) : buttonBackgroundColorForCurrentTheme)
                    .frame(width: 44, height: 44)
                
                Text(type == .white ? "W" : "B")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(baseNoiseType == type ? .white : textColorForCurrentTheme)
            }
        }
        .accessibilityLabel("\(type.displayName) noise")
        .accessibilityHint("Select \(type.displayName.lowercased()) as base noise")
    }
    
    /// Ambient sound button (ADD logic - multiple can be selected)
    private func ambientSoundButton(_ sound: AmbientSound) -> some View {
        Button(action: { toggleAmbientSound(sound) }) {
            ZStack {
                Circle()
                    .fill(activeAmbientSounds.contains(sound) ? ambientSoundBackgroundColor(for: sound) : buttonBackgroundColorForCurrentTheme)
                    .frame(width: 44, height: 44)
                
                Text(iconForAmbientSound(sound))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(activeAmbientSounds.contains(sound) ? .white : textColorForCurrentTheme)
            }
        }
        .accessibilityLabel("\(sound.displayName) ambient sound")
        .accessibilityHint(activeAmbientSounds.contains(sound) ? "Remove \(sound.displayName.lowercased()) sound" : "Add \(sound.displayName.lowercased()) sound")
    }
    
    /// Icon for ambient sounds
    private func iconForAmbientSound(_ sound: AmbientSound) -> String {
        switch sound {
        case .fire: return "🔥"
        case .rain: return "🌧️"
        case .birds: return "🐦"
        }
    }
    
    /// Background color for base noise type buttons
    private func baseNoiseBackgroundColor(for type: BaseNoiseType) -> Color {
        switch type {
        case .white: return .gray
        case .brown: return .brown
        }
    }
    
    /// Background color for ambient sound buttons
    private func ambientSoundBackgroundColor(for sound: AmbientSound) -> Color {
        switch sound {
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
            }
        } catch {
            print("Audio engine error: \(error.localizedDescription)")
            isPlaying = false
            isTransitioning = false
        }
    }
    
    /// Creates audio source node for noise generation based on current type
    private func createWhiteNoiseNode() -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for buffer in bufferListPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                
                // Pre-calculate gain once per buffer instead of per frame
                var finalGain: Float = 0.8
                let ambientCount = self.activeAmbientSounds.count
                if ambientCount > 1 {
                    finalGain *= (1.0 / Float(ambientCount)) * 0.7
                }
                
                // Cache active sounds check to avoid repeated Set.contains calls
                let hasFireSound = self.activeAmbientSounds.contains(.fire)
                let hasRainSound = self.activeAmbientSounds.contains(.rain)
                let hasBirdSound = self.activeAmbientSounds.contains(.birds)
                
                for frame in 0..<Int(frameCount) {
                    var output: Float = 0.0
                    self.frameCounter += 1
                    
                    // Generate base noise (required) - optimized random generation
                    switch self.baseNoiseType {
                    case .white:
                        output = Float.random(in: -0.5...0.5)
                    case .brown:
                        let whiteNoise = Float.random(in: -0.3...0.3)
                        self.brownNoiseFilter1 += 0.1 * (whiteNoise - self.brownNoiseFilter1)
                        output = self.brownNoiseFilter1 * 1.5
                    }
                    
                    // Fire sound - reduced computation frequency
                    if hasFireSound {
                        let rumbleNoise = Float.random(in: -0.2...0.2)
                        self.fireRumble += 0.008 * (rumbleNoise - self.fireRumble)
                        
                        let hissNoise = Float.random(in: -0.6...0.6)
                        self.fireHiss += 0.15 * (hissNoise - self.fireHiss)
                        
                        var pop1: Float = 0.0
                        if self.firePop1Timer > 0 {
                            let decay = Float(self.firePop1Timer) * 0.00833 // Pre-calculated 1/120
                            pop1 = self.firePop1Intensity * decay * decay
                            self.firePop1Timer -= 1
                        } else if self.frameCounter % 800 == 0 && arc4random_uniform(8) == 0 { // Reduced frequency
                            self.firePop1Timer = Int.random(in: 40...120)
                            self.firePop1Intensity = Float.random(in: 0.4...0.8)
                        }
                        
                        var pop2: Float = 0.0
                        if self.firePop2Timer > 0 {
                            let decay = Float(self.firePop2Timer) * 0.01 // Pre-calculated 1/100
                            pop2 = self.firePop2Intensity * decay * decay
                            self.firePop2Timer -= 1
                        } else if self.frameCounter % 700 == 0 && arc4random_uniform(12) == 0 {
                            self.firePop2Timer = Int.random(in: 30...100)
                            self.firePop2Intensity = Float.random(in: 0.3...0.6)
                        }
                        
                        // Simplified crackling - remove expensive sin calculation and random
                        if self.frameCounter % 20 == 0 {
                            self.fireCracklePhase += 0.1
                        }
                        let crackleTexture = self.fireCracklePhase * 0.01
                        
                        let fireOutput = self.fireRumble * 2.5 + self.fireHiss * 0.4 + pop1 * 1.2 + pop2 + crackleTexture
                        output += fireOutput * 0.25
                    }
                    
                    // Rain sound - reduced computation
                    if hasRainSound {
                        let baseRainNoise = Float.random(in: -0.3...0.3)
                        self.rainBaseNoise += 0.04 * (baseRainNoise - self.rainBaseNoise)
                        
                        var dropletNoise: Float = 0.0
                        if self.frameCounter % 100 == 0 && arc4random_uniform(20) == 0 { // Reduced frequency
                            dropletNoise = Float.random(in: -0.4...0.4) * Float.random(in: 0.2...0.4)
                        }
                        
                        self.rainSplashFilter += 0.15 * (dropletNoise - self.rainSplashFilter)
                        
                        if self.frameCounter % 160 == 0 { // Reduced frequency
                            let rumbleNoise = Float.random(in: -0.1...0.1)
                            self.rainDropletState += 0.02 * (rumbleNoise - self.rainDropletState)
                        }
                        
                        let rainOutput = self.rainBaseNoise * 0.8 + dropletNoise * 0.2 + self.rainSplashFilter * 0.2 + self.rainDropletState * 0.8
                        output += rainOutput * 0.2
                    }
                    
                    // Bird sound - simplified oscillation
                    if hasBirdSound {
                        var birdCall: Float = 0.0
                        
                        if self.birdCallTimer > 0 {
                            // Simplified bird call - remove expensive sin calculations
                            let callProgress = Float(self.birdCallTimer) * 0.00125 // Pre-calculated 1/800
                            let frequency = callProgress * 15.0 // Remove sin calculation
                            birdCall = self.birdCallIntensity * frequency * 0.5 // Simplified
                            self.birdCallTimer -= 1
                        } else if self.frameCounter % 600 == 0 && arc4random_uniform(15) == 0 { // Reduced frequency
                            self.birdCallTimer = Int.random(in: 200...800)
                            self.birdCallIntensity = Float.random(in: 0.1...0.3)
                        }
                        
                        self.birdCallFilter += 0.3 * (birdCall - self.birdCallFilter)
                        
                        var backgroundChirp: Float = 0.0
                        if self.frameCounter % 300 == 0 && arc4random_uniform(30) == 0 { // Reduced frequency
                            backgroundChirp = Float.random(in: -0.1...0.1) * Float.random(in: 0.2...0.4)
                        }
                        
                        let birdOutput = self.birdCallFilter + backgroundChirp * 0.5
                        output += birdOutput * 0.15
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
        guard let engine = audioEngine else { return }
        
        // Set stopped state immediately for smooth UI feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = false
        }
        
        fadeOut(engine.mainMixerNode) {
            engine.stop()
            audioEngine = nil
            whiteNoiseNode = nil
            isTransitioning = false
        }
    }

    // MARK: - Audio Fading
    
    /// Gradually increases volume from 0 to system volume
    private func fadeIn(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        performFade(mixerNode: mixerNode, duration: duration, startVolume: 0.0, endVolume: 1.0, completion: completion)
    }

    /// Gradually decreases volume to 0 then executes completion
    private func fadeOut(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 0.5, completion: @escaping () -> Void) {
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
    
    /// Selects base noise type (OR logic)
    private func selectBaseNoise(_ type: BaseNoiseType) {
        guard baseNoiseType != type else { return }
        
        triggerLightHapticFeedback()
        baseNoiseType = type
        
        // If audio is playing, restart with new base
        if isPlaying {
            restartAudioWithCurrentSettings()
        }
    }
    
    /// Toggles ambient sound (ADD logic)
    private func toggleAmbientSound(_ sound: AmbientSound) {
        triggerLightHapticFeedback()
        
        if activeAmbientSounds.contains(sound) {
            activeAmbientSounds.remove(sound)
        } else {
            activeAmbientSounds.insert(sound)
        }
        
        // If audio is playing, restart with new mix
        if isPlaying {
            restartAudioWithCurrentSettings()
        }
    }
    
    /// Restarts audio with current base noise and ambient sounds
    private func restartAudioWithCurrentSettings() {
        guard let engine = audioEngine else { return }
        
        // Fade out current audio
        fadeOut(engine.mainMixerNode, duration: 0.2) {
            // Reset all filter states
            self.brownNoiseFilter1 = 0.0
            self.fireRumble = 0.0
            self.fireHiss = 0.0
            self.firePop1Timer = 0
            self.firePop1Intensity = 0.0
            self.firePop2Timer = 0
            self.firePop2Intensity = 0.0
            self.fireCracklePhase = 0.0
            self.rainDropletState = 0.0
            self.rainSplashFilter = 0.0
            self.rainBaseNoise = 0.0
            self.birdCallTimer = 0
            self.birdCallIntensity = 0.0
            self.birdCallFilter = 0.0
            self.frameCounter = 0
            
            // Stop and restart audio engine
            engine.stop()
            self.audioEngine = nil
            self.whiteNoiseNode = nil
            
            // Small delay then restart with current settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.playWhiteNoise()
            }
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
