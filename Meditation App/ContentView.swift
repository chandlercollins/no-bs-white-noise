import SwiftUI
import AVFoundation
import UIKit

/// Theme mode options for the application
enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"
    
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "a.circle.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

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
    @State private var isTransitioning = false
    @State private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    
    // MARK: - Environment
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ZStack {
            // Background
            backgroundColorForCurrentTheme
                .ignoresSafeArea(.all)
            
            VStack(spacing: 40) {
                // Theme toggle button in top-right corner
                HStack {
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
            }
        }
        .padding()
        .preferredColorScheme(preferredColorScheme)
    }
    
    // MARK: - UI Components
    
    /// Play/Stop button with pulse animation
    private var playStopButton: some View {
        Button(action: togglePlayback) {
            ZStack {
                Circle()
                    .fill(isPlaying ? playButtonStopColor : playButtonPlayColor)
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
            .accentColor(sliderAccentColor)
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
        .accessibilityLabel("Theme: \(themeMode.displayName)")
        .accessibilityHint("Double tap to switch between light, dark, and auto themes")
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
        case .auto: return nil // Uses system setting
        }
    }
    
    /// Returns the current effective color scheme
    private var effectiveColorScheme: ColorScheme {
        switch themeMode {
        case .light: return .light
        case .dark: return .dark
        case .auto: return systemColorScheme
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
            fadeIn(engine.mainMixerNode) {
                self.isTransitioning = false
            }
            isPlaying = true
        } catch {
            print("Audio engine error: \(error.localizedDescription)")
            isTransitioning = false
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
    
    /// Cycles through theme modes: light → dark → auto → light
    private func cycleThemeMode() {
        triggerLightHapticFeedback()
        
        switch themeMode {
        case .light:
            themeMode = .dark
        case .dark:
            themeMode = .auto
        case .auto:
            themeMode = .light
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
