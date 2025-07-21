import SwiftUI
import AVFoundation
import UIKit
import MediaPlayer

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
    @State private var rainAudioPlayer: AVAudioPlayer?
    @State private var birdsAudioPlayer: AVAudioPlayer?
    @State private var preloadedFirePlayer: AVAudioPlayer?
    @State private var preloadedRainPlayer: AVAudioPlayer?
    @State private var preloadedBirdsPlayer: AVAudioPlayer?
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
    @State private var secondBirdTimer: Int = 0
    @State private var secondBirdIntensity: Float = 0.0
    @State private var thirdBirdTimer: Int = 0
    @State private var thirdBirdIntensity: Float = 0.0
    @State private var birdSpeciesSwitch: Int = 0
    @State private var insectChirpTimer: Int = 0
    @State private var frameCounter: Int = 0
    @State private var rainIntensity: Float = 0.7
    @State private var windGustPhase: Float = 0.0
    
    // MARK: - UI State
    @State private var isPlaying = false
    @State private var pulseAnimation = false
    @State private var isTransitioning = false
    @State private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    @State private var selectedSoundType: SoundType = .white // Default sound - button will show as active
    @State private var isMenuExpanded = false
    @State private var isSoundTransitioning = false
    @State private var screenDimTimer: Timer?
    @State private var lastUserInteraction: Date = Date()
    
    // MARK: - Environment
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            // Background
            backgroundColorForCurrentTheme
                .ignoresSafeArea(.all)
            
            VStack(spacing: mainVerticalSpacing) {
                // Top navigation bar with logo and theme toggle
                HStack {
                    logoView
                    Spacer()
                    themeToggleButton
                }
                .padding(.top, topPadding)
                
                Spacer()
                
                // Main content
                VStack(spacing: mainVerticalSpacing) {
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
            
            // Initialize screen management
            setupScreenManagement()
            
            // Preload audio files to prevent hitches
            preloadAudioFiles()
            
            // Set up remote control commands for Control Center
            setupRemoteCommandCenter()
        }
        .onChange(of: isPlaying) { _, newValue in
            // Update screen dimming behavior based on playback state
            updateScreenDimming(isPlaying: newValue)
            
            // Update Control Center info
            updateNowPlayingInfo()
        }
        .onDisappear {
            // Clean up timers and audio when view disappears
            fadeTimer?.invalidate()
            fadeTimer = nil
            screenDimTimer?.invalidate()
            screenDimTimer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            handleAudioInterruption(notification)
        }
        .onTapGesture {
            // Track user interaction for screen dimming
            recordUserInteraction()
        }
    }
    
    // MARK: - UI Components
    
    /// App logo with theme-aware styling and responsive sizing
    private var logoView: some View {
        VStack(alignment: .leading, spacing: logoSpacing) {
            // Handwritten correction
            Text("No-BS")
                .font(.system(size: logoSubtitleSize, weight: .medium, design: .default))
                .foregroundColor(textColorForCurrentTheme.opacity(0.8))
                .italic()
            
            // Main logo text
            HStack(spacing: 0) {
                Text("White")
                    .font(.system(size: logoTitleSize, weight: .bold, design: .default))
                    .foregroundColor(textColorForCurrentTheme)
                Text(" Noise")
                    .font(.system(size: logoTitleSize, weight: .regular, design: .default))
                    .foregroundColor(textColorForCurrentTheme)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: effectiveColorScheme)
    }
    
    /// Play/Stop button with pulse animation and responsive sizing
    private var playStopButton: some View {
        Button(action: togglePlayback) {
            ZStack {
                Circle()
                    .fill(isPlaying ? playButtonStopColor : playButtonPlayColor)
                    .frame(width: playButtonSize, height: playButtonSize)
                    .scaleEffect(pulseAnimation ? (isPlaying ? 1.15 : 1.05) : 1.0)
                    .animation(
                        pulseAnimation ? 
                        .easeInOut(duration: isPlaying ? 1.0 : 2.0).repeatForever(autoreverses: true) : 
                        .easeInOut(duration: 0.3), 
                        value: pulseAnimation
                    )
                
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: playButtonIconSize))
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
    
    /// Theme toggle button with appropriate icon and responsive sizing
    private var themeToggleButton: some View {
        Button(action: cycleThemeMode) {
            Image(systemName: themeMode.iconName)
                .font(.system(size: themeButtonIconSize, weight: .regular))
                .foregroundColor(textColorForCurrentTheme)
                .frame(width: themeButtonSize, height: themeButtonSize)
                .background(
                    Circle()
                        .fill(buttonBackgroundColorForCurrentTheme)
                        .overlay(
                            Circle()
                                .stroke(textColorForCurrentTheme.opacity(0.2), lineWidth: themeButtonStrokeWidth)
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
    
    // MARK: - Responsive Design Properties
    
    /// Determines if we're on an iPad-sized device
    private var isIPadInterface: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    /// Scaling factor for UI elements based on device size
    private var scalingFactor: CGFloat {
        isIPadInterface ? 1.6 : 1.0
    }
    
    /// Logo title font size that scales with device
    private var logoTitleSize: CGFloat {
        let baseSize: CGFloat = 22 // .title2 equivalent
        return baseSize * scalingFactor
    }
    
    /// Logo subtitle font size that scales with device
    private var logoSubtitleSize: CGFloat {
        let baseSize: CGFloat = 12 // .caption equivalent
        return baseSize * scalingFactor
    }
    
    /// Spacing between logo elements that scales with device
    private var logoSpacing: CGFloat {
        let baseSpacing: CGFloat = -2
        return baseSpacing * scalingFactor
    }
    
    /// Theme button size that scales with device
    private var themeButtonSize: CGFloat {
        let baseSize: CGFloat = 44
        return baseSize * scalingFactor
    }
    
    /// Theme button icon size that scales with device
    private var themeButtonIconSize: CGFloat {
        let baseSize: CGFloat = 22 // .title2 equivalent
        return baseSize * scalingFactor
    }
    
    /// Theme button stroke width that scales with device
    private var themeButtonStrokeWidth: CGFloat {
        let baseWidth: CGFloat = 1
        return baseWidth * scalingFactor
    }
    
    /// Play button size that scales with device
    private var playButtonSize: CGFloat {
        let baseSize: CGFloat = 150
        return baseSize * scalingFactor
    }
    
    /// Play button icon size that scales with device
    private var playButtonIconSize: CGFloat {
        let baseSize: CGFloat = 50
        return baseSize * scalingFactor
    }
    
    /// Sound button size that scales with device
    private var soundButtonSize: CGFloat {
        let baseSize: CGFloat = 44
        return baseSize * scalingFactor
    }
    
    /// Sound button icon size that scales with device
    private var soundButtonIconSize: CGFloat {
        let baseSize: CGFloat = 22 // .title2 equivalent
        return baseSize * scalingFactor
    }
    
    /// Main vertical spacing that scales with device
    private var mainVerticalSpacing: CGFloat {
        let baseSpacing: CGFloat = 40
        return baseSpacing * scalingFactor
    }
    
    /// Top padding that scales with device
    private var topPadding: CGFloat {
        let basePadding: CGFloat = 16
        return basePadding * scalingFactor
    }
    
    /// Bottom menu padding that scales with device
    private var bottomMenuPadding: CGFloat {
        let basePadding: CGFloat = 20
        return basePadding * scalingFactor
    }
    
    /// Sound menu horizontal padding that scales with device
    private var soundMenuHorizontalPadding: CGFloat {
        let basePadding: CGFloat = 24
        return basePadding * scalingFactor
    }
    
    /// Menu overlay height that scales with device
    private var menuOverlayHeight: CGFloat {
        let baseHeight: CGFloat = 120
        return baseHeight * scalingFactor
    }
    
    /// Menu caret icon size that scales with device
    private var menuCaretIconSize: CGFloat {
        let baseSize: CGFloat = 22 // .title2 equivalent
        return baseSize * scalingFactor
    }
    
    /// Menu top padding that scales with device
    private var menuTopPadding: CGFloat {
        let basePadding: CGFloat = 16
        return basePadding * scalingFactor
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
    
    
    /// Bottom menu button with up caret and responsive sizing
    private var bottomMenuButton: some View {
        Button(action: toggleMenu) {
            Image(systemName: "chevron.up")
                .font(.system(size: menuCaretIconSize))
                .foregroundColor(textColorForCurrentTheme.opacity(0.7))
                .rotationEffect(.degrees(isMenuExpanded ? 180 : 0))
                .animation(.easeInOut(duration: 0.3), value: isMenuExpanded)
        }
        .padding(.bottom, bottomMenuPadding)
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
                            .font(.system(size: menuCaretIconSize))
                            .foregroundColor(menuHandleColor)
                            .rotationEffect(.degrees(180)) // Point down to indicate close
                    }
                    Spacer()
                }
                .padding(.top, menuTopPadding)
                
                // Center the sound buttons vertically in remaining space
                Spacer()
                
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
                .padding(.horizontal, soundMenuHorizontalPadding)
                
                // Equal space below to center the buttons
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: menuOverlayHeight)
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
    
    /// Sound button - only one can be selected at a time with responsive sizing
    private func soundButton(_ type: SoundType) -> some View {
        Button(action: { selectSound(type) }) {
            ZStack {
                Circle()
                    .fill(selectedSoundType == type ? soundBackgroundColor(for: type) : buttonBackgroundColorForCurrentTheme)
                    .frame(width: soundButtonSize, height: soundButtonSize)
                
                Text(iconForSound(type))
                    .font(.system(size: soundButtonIconSize, weight: .bold))
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
        
        // Record user interaction for screen dimming
        recordUserInteraction()
        
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
        // Configure audio session for exclusive background playback (works in silent mode and background)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration error: \(error.localizedDescription)")
        }
        
        // Ensure selectedSoundType reflects what's actually being played
        // This ensures the menu button shows as active even if menu was never opened
        
        // Handle MP3 audio files
        if selectedSoundType == .fire {
            playFireAudio()
            return
        }
        
        if selectedSoundType == .rain {
            playRainAudio()
            return
        }
        
        if selectedSoundType == .birds {
            playBirdsAudio()
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
    
    /// Plays fire audio using preloaded AVAudioPlayer for instant playback
    private func playFireAudio() {
        guard let player = preloadedFirePlayer else {
            print("Preloaded fire audio player not available")
            isPlaying = false
            isTransitioning = false
            return
        }
        
        // Use the preloaded player as the active player
        fireAudioPlayer = player
        fireAudioPlayer?.numberOfLoops = -1 // Infinite loop
        
        // Start at random position in the MP3 for variety
        let duration = fireAudioPlayer?.duration ?? 0
        if duration > 0 {
            let randomStart = TimeInterval.random(in: 0...(duration * 0.9)) // Don't start too close to end
            fireAudioPlayer?.currentTime = randomStart
        }
        
        fireAudioPlayer?.play()
        
        // Set playing state immediately for smooth UI feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = true
        }
        
        isTransitioning = false
    }
    
    /// Plays rain audio using preloaded AVAudioPlayer for instant playback
    private func playRainAudio() {
        guard let player = preloadedRainPlayer else {
            print("Preloaded rain audio player not available")
            isPlaying = false
            isTransitioning = false
            return
        }
        
        // Use the preloaded player as the active player
        rainAudioPlayer = player
        rainAudioPlayer?.numberOfLoops = -1 // Infinite loop
        
        // Start at random position in the MP3 for variety
        let duration = rainAudioPlayer?.duration ?? 0
        if duration > 0 {
            let randomStart = TimeInterval.random(in: 0...(duration * 0.9)) // Don't start too close to end
            rainAudioPlayer?.currentTime = randomStart
        }
        
        rainAudioPlayer?.play()
        
        // Set playing state immediately for smooth UI feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = true
        }
        
        isTransitioning = false
    }
    
    /// Plays birds audio using preloaded AVAudioPlayer for instant playback
    private func playBirdsAudio() {
        guard let player = preloadedBirdsPlayer else {
            print("Preloaded birds audio player not available")
            isPlaying = false
            isTransitioning = false
            return
        }
        
        // Use the preloaded player as the active player
        birdsAudioPlayer = player
        birdsAudioPlayer?.numberOfLoops = -1 // Infinite loop
        
        // Start at random position in the MP3 for variety
        let duration = birdsAudioPlayer?.duration ?? 0
        if duration > 0 {
            let randomStart = TimeInterval.random(in: 0...(duration * 0.9)) // Don't start too close to end
            birdsAudioPlayer?.currentTime = randomStart
        }
        
        birdsAudioPlayer?.play()
        
        // Set playing state immediately for smooth UI feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = true
        }
        
        isTransitioning = false
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
                        let whiteNoise = Float.random(in: -0.5...0.5)
                        self.brownNoiseFilter1 += 0.1 * (whiteNoise - self.brownNoiseFilter1)
                        output = self.brownNoiseFilter1 * 1.8
                    case .fire:
                        // Fire sound is handled by AVAudioPlayer - this should not be called
                        output = 0.0
                    case .rain:
                        // Rain sound is handled by AVAudioPlayer - this should not be called
                        output = 0.0
                    case .birds:
                        // Birds sound is handled by AVAudioPlayer - this should not be called
                        output = 0.0
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
        
        // Stop MP3 audio players if they're playing
        if let firePlayer = fireAudioPlayer {
            firePlayer.stop()
            fireAudioPlayer = nil
            isTransitioning = false
            
            // Don't deactivate audio session - let system manage it
            return
        }
        
        if let rainPlayer = rainAudioPlayer {
            rainPlayer.stop()
            rainAudioPlayer = nil
            isTransitioning = false
            
            // Don't deactivate audio session - let system manage it
            return
        }
        
        if let birdsPlayer = birdsAudioPlayer {
            birdsPlayer.stop()
            birdsAudioPlayer = nil
            isTransitioning = false
            
            // Don't deactivate audio session - let system manage it
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
        
        let fadeSteps = 20
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
        // Record user interaction for screen dimming
        recordUserInteraction()
        
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
        // Record user interaction for screen dimming
        recordUserInteraction()
        
        triggerLightHapticFeedback()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isMenuExpanded.toggle()
        }
    }
    
    /// Selects sound type - only one at a time with debouncing
    private func selectSound(_ type: SoundType) {
        // Prevent rapid button mashing
        guard selectedSoundType != type && !isSoundTransitioning else { return }
        
        // Record user interaction for screen dimming
        recordUserInteraction()
        
        triggerLightHapticFeedback()
        
        // Set transitioning flag immediately
        isSoundTransitioning = true
        selectedSoundType = type
        
        // Update Now Playing info with new sound type
        updateNowPlayingInfo()
        
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
        // Check if we're currently using MP3 audio players
        let wasUsingMp3Audio = (fireAudioPlayer != nil || rainAudioPlayer != nil || birdsAudioPlayer != nil)
        let willUseMp3Audio = (selectedSoundType == .fire || selectedSoundType == .rain || selectedSoundType == .birds)
        
        // For same audio system (generated to generated), just reset state
        if !wasUsingMp3Audio && !willUseMp3Audio {
            // Reset all filter states immediately for clean transition
            brownNoiseFilter1 = 0.0
            birdCallTimer = 0
            birdCallIntensity = 0.0
            birdCallFilter = 0.0
            secondBirdTimer = 0
            secondBirdIntensity = 0.0
            thirdBirdTimer = 0
            thirdBirdIntensity = 0.0
            birdSpeciesSwitch = 0
            insectChirpTimer = 0
            frameCounter = 0
            windGustPhase = 0.0
            
            // Clear transition flag immediately for generated sounds
            isSoundTransitioning = false
            return
        }
        
        // For switching between audio systems (generated ↔ MP3)
        stopWhiteNoise()
        
        // Minimal delay for MP3 sound transitions
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
    
    // MARK: - Audio Preloading
    
    /// Preloads all MP3 audio files to prevent hitches when switching sounds
    private func preloadAudioFiles() {
        // Preload fire audio
        if let path = Bundle.main.path(forResource: "fire", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                preloadedFirePlayer = try AVAudioPlayer(contentsOf: url)
                preloadedFirePlayer?.prepareToPlay()
                preloadedFirePlayer?.volume = 0.8
            } catch {
                print("Failed to preload fire audio: \(error.localizedDescription)")
            }
        }
        
        // Preload rain audio
        if let path = Bundle.main.path(forResource: "rain", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                preloadedRainPlayer = try AVAudioPlayer(contentsOf: url)
                preloadedRainPlayer?.prepareToPlay()
                preloadedRainPlayer?.volume = 0.4
            } catch {
                print("Failed to preload rain audio: \(error.localizedDescription)")
            }
        }
        
        // Preload birds audio
        if let path = Bundle.main.path(forResource: "birdsounds", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                preloadedBirdsPlayer = try AVAudioPlayer(contentsOf: url)
                preloadedBirdsPlayer?.prepareToPlay()
                preloadedBirdsPlayer?.volume = 0.3
            } catch {
                print("Failed to preload birds audio: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Screen Management
    
    /// Sets up intelligent screen dimming based on Apple's best practices
    private func setupScreenManagement() {
        // Initially allow normal screen dimming
        UIApplication.shared.isIdleTimerDisabled = false
        lastUserInteraction = Date()
    }
    
    /// Updates screen dimming behavior when playback state changes
    private func updateScreenDimming(isPlaying: Bool) {
        if isPlaying {
            // When audio starts, prevent immediate dimming but allow delayed dimming
            resetScreenDimTimer()
        } else {
            // When audio stops, return to normal system dimming
            UIApplication.shared.isIdleTimerDisabled = false
            screenDimTimer?.invalidate()
        }
    }
    
    /// Records user interaction and resets screen dim timer
    private func recordUserInteraction() {
        lastUserInteraction = Date()
        
        // If audio is playing, reset the dimming timer
        if isPlaying {
            resetScreenDimTimer()
        }
    }
    
    /// Resets screen dim timer following Apple's recommendations
    private func resetScreenDimTimer() {
        // Cancel existing timer
        screenDimTimer?.invalidate()
        
        // Prevent immediate dimming
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Apple's recommendation: 30 seconds of inactivity before allowing screen to dim
        // This balances user experience with battery life
        screenDimTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            // After 30 seconds of inactivity, allow system to dim screen
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - Remote Control / Now Playing
    
    /// Sets up Control Center and lock screen remote controls
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Enable play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            if !self.isPlaying {
                self.togglePlayback()
            }
            return .success
        }
        
        // Enable pause command  
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            if self.isPlaying {
                self.togglePlayback()
            }
            return .success
        }
        
        // Enable toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            self.togglePlayback()
            return .success
        }
    }
    
    /// Updates Now Playing info for Control Center and lock screen
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(selectedSoundType.displayName) Noise"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "No-BS White Noise"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Audio Interruption Handling
    
    /// Handles audio interruptions from phone calls, other apps, etc.
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio was interrupted (phone call, other app started playing)
            if isPlaying {
                // Update UI to reflect that audio is paused
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPlaying = false
                }
            }
        case .ended:
            // Interruption ended - don't automatically resume, let user control
            break
        @unknown default:
            break
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
