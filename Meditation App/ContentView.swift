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

/// Noise type options for audio generation
enum NoiseType: String, CaseIterable {
    case white = "white"
    case brown = "brown"
    
    var displayName: String {
        switch self {
        case .white: return "White"
        case .brown: return "Brown"
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
    
    // MARK: - UI State
    @State private var isPlaying = false
    @State private var pulseAnimation = false
    @State private var volume: Float = 1.0
    @State private var isTransitioning = false
    @State private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    @State private var noiseType: NoiseType = .white
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
                    volumeSlider
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
        .onChange(of: isPlaying) { newValue in
            // Smooth transition with slight delay to prevent conflicts
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseAnimation = newValue
            }
        }
    }
    
    /// Volume control slider with Liquid Glass design
    private var volumeSlider: some View {
        VStack(spacing: 8) {
            // Volume icon
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColorForCurrentTheme.opacity(0.7))
            
            // Custom liquid glass slider
            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(sliderTrackBackground)
                    .frame(height: 6)
                
                // Active track fill
                HStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(sliderActiveTrack)
                        .frame(height: 6)
                        .scaleEffect(x: CGFloat(volume), anchor: .leading)
                    Spacer(minLength: 0)
                }
                
                // Glass thumb
                HStack {
                    Spacer()
                        .frame(width: CGFloat(volume) * 180) // 200 - 20 for thumb width
                    
                    sliderThumb
                    
                    Spacer()
                }
            }
            .frame(width: 200)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newValue = max(0, min(1, Float(value.location.x / 200)))
                        volume = newValue
                        updateVolume()
                    }
            )
        }
    }
    
    /// Liquid glass slider thumb with interactive scaling
    private var sliderThumb: some View {
        Circle()
            .fill(sliderThumbColor)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: volume)
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
    
    /// Slider accent color with theme awareness
    private var sliderAccentColor: Color {
        effectiveColorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
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
    
    /// Slider track background with Liquid Glass aesthetic
    private var sliderTrackBackground: some View {
        ZStack {
            if effectiveColorScheme == .dark {
                Color.white.opacity(0.1)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Color.black.opacity(0.06)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
    
    /// Active slider track with theme-aware coloring
    private var sliderActiveTrack: Color {
        effectiveColorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue
    }
    
    /// Slider thumb color with glass effect
    private var sliderThumbColor: Color {
        effectiveColorScheme == .dark ? Color.white.opacity(0.9) : Color.white
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
                
                // Noise type selector
                HStack(spacing: 30) {
                    noiseTypeButton(.white)
                    noiseTypeButton(.brown)
                    Spacer()
                }
                .padding(.horizontal, 24)
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
    
    /// Noise type toggle button
    private func noiseTypeButton(_ type: NoiseType) -> some View {
        Button(action: { toggleNoiseType(to: type) }) {
            ZStack {
                Circle()
                    .fill(noiseType == type ? noiseTypeBackgroundColor(for: type) : buttonBackgroundColorForCurrentTheme)
                    .frame(width: 50, height: 50)
                
                Text(type == .white ? "W" : "B")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(noiseType == type ? .white : textColorForCurrentTheme)
            }
        }
        .accessibilityLabel("\(type.displayName) noise")
        .accessibilityHint("Switch to \(type.displayName.lowercased()) noise")
    }
    
    /// Background color for noise type buttons
    private func noiseTypeBackgroundColor(for type: NoiseType) -> Color {
        switch type {
        case .white: return .gray
        case .brown: return .brown
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
                
                switch self.noiseType {
                case .white:
                    // White noise: equal energy across all frequencies
                    for frame in 0..<Int(frameCount) {
                        data[frame] = Float.random(in: -0.5...0.5)
                    }
                case .brown:
                    // Brown noise: gentle single-pole low-pass filter for warmer tone
                    // Much more conservative approach to avoid speaker stress
                    for frame in 0..<Int(frameCount) {
                        let whiteNoise = Float.random(in: -0.3...0.3)
                        
                        // Simple single-pole low-pass filter with very gentle rolloff
                        let alpha: Float = 0.1  // Much higher cutoff, gentler filtering
                        self.brownNoiseFilter1 += alpha * (whiteNoise - self.brownNoiseFilter1)
                        
                        // Output the filtered result with conservative gain
                        data[frame] = self.brownNoiseFilter1 * 1.5
                    }
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
    
    /// Gradually increases volume from 0 to current volume setting
    private func fadeIn(_ mixerNode: AVAudioMixerNode, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        performFade(mixerNode: mixerNode, duration: duration, startVolume: 0.0, endVolume: volume, completion: completion)
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

    /// Updates the audio engine volume to match current volume setting
    private func updateVolume() {
        audioEngine?.mainMixerNode.outputVolume = volume
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
    
    /// Switches to specified noise type
    private func toggleNoiseType(to type: NoiseType) {
        guard noiseType != type else { return }
        
        triggerLightHapticFeedback()
        
        // If audio is playing, do smooth transition with fade
        if isPlaying {
            guard let engine = audioEngine else { return }
            
            // Fade out current audio
            fadeOut(engine.mainMixerNode, duration: 0.2) {
                // Reset filter state and change noise type
                self.brownNoiseFilter1 = 0.0
                self.noiseType = type
                
                // Stop and restart audio engine
                engine.stop()
                self.audioEngine = nil
                self.whiteNoiseNode = nil
                
                // Small delay then restart with new noise type
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.playWhiteNoise()
                }
            }
        } else {
            // Not playing, just change type and reset state
            brownNoiseFilter1 = 0.0
            noiseType = type
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
