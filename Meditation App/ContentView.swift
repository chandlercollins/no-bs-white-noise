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
    case ocean = "ocean"
    case wind = "wind"
    
    var displayName: String {
        switch self {
        case .fire: return "Fire"
        case .ocean: return "Ocean"
        case .wind: return "Wind"
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
    @State private var fireNoiseState: Float = 0.0
    @State private var fireHissFilter: Float = 0.0
    @State private var crackleDuration: Int = 0
    @State private var crackleIntensity: Float = 0.0
    @State private var emberGlow: Float = 0.0
    
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
            
            // Unified sliding overlay with caret at top
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
                HStack(spacing: 15) {
                    // Base noise types (left side - OR logic)
                    baseNoiseButton(.white)
                    baseNoiseButton(.brown)
                    
                    // Vertical separator line
                    Rectangle()
                        .fill(menuHandleColor)
                        .frame(width: 1, height: 30)
                        .padding(.horizontal, 8)
                    
                    // Ambient sounds (right side - ADD logic)
                    ambientSoundButton(.fire)
                    ambientSoundButton(.ocean)
                    ambientSoundButton(.wind)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
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
        case .ocean: return "🌊"
        case .wind: return "💨"
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
        case .ocean: return .blue
        case .wind: return .cyan
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
                
                for frame in 0..<Int(frameCount) {
                    var output: Float = 0.0
                    
                    // Generate base noise (required)
                    switch self.baseNoiseType {
                    case .white:
                        // White noise: equal energy across all frequencies
                        output = Float.random(in: -0.5...0.5)
                    case .brown:
                        // Brown noise: gentle single-pole low-pass filter for warmer tone
                        let whiteNoise = Float.random(in: -0.3...0.3)
                        let alpha: Float = 0.1  // Much higher cutoff, gentler filtering
                        self.brownNoiseFilter1 += alpha * (whiteNoise - self.brownNoiseFilter1)
                        output = self.brownNoiseFilter1 * 1.5
                    }
                    
                    // Add ambient sounds (optional mix-ins)
                    if self.activeAmbientSounds.contains(.fire) {
                        // Realistic fireplace crackling
                        let baseNoise = Float.random(in: -0.15...0.15)
                        let rumbleAlpha: Float = 0.02
                        self.fireNoiseState += rumbleAlpha * (baseNoise - self.fireNoiseState)
                        
                        let hissNoise = Float.random(in: -0.8...0.8)
                        let hissAlpha: Float = 0.3
                        self.fireHissFilter += hissAlpha * (hissNoise - self.fireHissFilter)
                        
                        var crackle: Float = 0.0
                        if self.crackleDuration > 0 {
                            let decay = Float(self.crackleDuration) / 2000.0
                            crackle = self.crackleIntensity * decay * Float.random(in: 0.7...1.3)
                            self.crackleDuration -= 1
                        } else if arc4random_uniform(3000) == 0 {
                            self.crackleDuration = Int.random(in: 200...2000)
                            self.crackleIntensity = Float.random(in: 0.2...0.6)
                        }
                        
                        self.emberGlow += 0.001 * (Float.random(in: -0.1...0.1) - self.emberGlow)
                        
                        let fireOutput = (self.fireNoiseState * 2.0) +
                                        (self.fireHissFilter * 0.15) +
                                        crackle +
                                        (self.emberGlow * 0.8)
                        
                        output += fireOutput * 0.4 // Mix at lower level
                    }
                    
                    if self.activeAmbientSounds.contains(.ocean) {
                        // Placeholder ocean sound (will be implemented later)
                        output += Float.random(in: -0.2...0.2) * 0.3
                    }
                    
                    if self.activeAmbientSounds.contains(.wind) {
                        // Placeholder wind sound (will be implemented later)
                        output += Float.random(in: -0.3...0.3) * 0.25
                    }
                    
                    data[frame] = output * 0.8 // Final level adjustment
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
            self.fireNoiseState = 0.0
            self.fireHissFilter = 0.0
            self.crackleDuration = 0
            self.crackleIntensity = 0.0
            self.emberGlow = 0.0
            
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
