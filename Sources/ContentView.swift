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
    // MARK: - Audio Properties (Simplified for Performance)
    @State private var audioEngine: AVAudioEngine?
    @State private var whiteNoiseNode: AVAudioSourceNode?
    @State private var currentAudioPlayer: AVAudioPlayer?
    @State private var preloadedPlayers: [SoundType: AVAudioPlayer] = [:]
    @State private var brownNoiseFilter: Float = 0.0
    @State private var frameCounter: Int = 0
    
    // MARK: - UI State (Optimized)
    @State private var isPlaying = false
    @State private var pulseAnimation = false
    @State private var handlePulseAnimation = false
    @State private var isTransitioning = false
    @State private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    @State private var selectedSoundType: SoundType = .white
    @State private var isMenuExpanded = false
    @State private var lastUserInteraction: Date = Date()

    // MARK: - Task Management
    @State private var audioTask: Task<Void, Never>?
    @State private var screenDimTask: Task<Void, Error>?

    // MARK: - Environment
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            // Apple Sports-inspired gradient background - covers entire screen
            backgroundForCurrentTheme
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
            .padding() // Only apply padding to content, not background
            
            // Overlay menu
            if isMenuExpanded {
                menuOverlay
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { gesture in
                    let verticalMovement = gesture.translation.height
                    let horizontalMovement = abs(gesture.translation.width)

                    // Only respond to primarily vertical swipes
                    if abs(verticalMovement) > horizontalMovement {
                        if verticalMovement < -50 && !isMenuExpanded {
                            // Swipe up to open menu
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuExpanded = true
                            }
                        } else if verticalMovement > 50 && isMenuExpanded {
                            // Swipe down to close menu
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                            }
                        }
                    }
                }
        )
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            // Set initial theme to match system on first launch
            if UserDefaults.standard.object(forKey: "hasLaunchedBefore") == nil {
                themeMode = systemColorScheme == .dark ? .dark : .light
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            }

            // Initialize screen management
            setupScreenManagement()

            // Preload audio files to prevent hitches
            preloadAudioFiles()

            // Set up remote control commands for Control Center
            setupRemoteCommandCenter()

            // Setup Siri intent listener
            setupSiriIntentListener()
            
            // Start handle pulse animation after a short delay to draw attention
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    handlePulseAnimation = true
                }
                
                // Stop the pulse after a few cycles
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        handlePulseAnimation = false
                    }
                }
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            // Update screen dimming behavior based on playback state
            updateScreenDimming(isPlaying: newValue)
            
            // Update Control Center info
            updateNowPlayingInfo()
        }
        .onDisappear {
            // Clean up all resources when view disappears
            cleanupAllResources()
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
    
    /// App logo with immersive Liquid Glass styling and depth
    private var logoView: some View {
        VStack(alignment: .leading, spacing: logoSpacing) {
            // Handwritten correction with enhanced glass depth
            Text("No-BS")
                .font(.system(size: logoSubtitleSize, weight: .medium, design: .default))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.secondary.opacity(0.9),
                            Color.secondary.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .italic()
                .shadow(
                    color: effectiveColorScheme == .dark ?
                        .white.opacity(0.08) : .black.opacity(0.12),
                    radius: 1,
                    x: 0,
                    y: 0.5
                )

            // Main logo text with prominent glass effects and depth
            HStack(spacing: 0) {
                Text("White")
                    .font(.system(size: logoTitleSize, weight: .bold, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.98),
                                Color.primary.opacity(0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: effectiveColorScheme == .dark ?
                            .white.opacity(0.2) : .white.opacity(0.4),
                        radius: 2,
                        x: 0,
                        y: -0.5
                    )
                    .shadow(
                        color: effectiveColorScheme == .dark ?
                            .black.opacity(0.4) : .black.opacity(0.15),
                        radius: 3,
                        x: 0,
                        y: 1.5
                    )

                Text(" Noise")
                    .font(.system(size: logoTitleSize, weight: .regular, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.85),
                                Color.primary.opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: effectiveColorScheme == .dark ?
                            .white.opacity(0.1) : .white.opacity(0.3),
                        radius: 1.5,
                        x: 0,
                        y: -0.5
                    )
                    .shadow(
                        color: effectiveColorScheme == .dark ?
                            .black.opacity(0.3) : .black.opacity(0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: effectiveColorScheme)
    }
    
    /// Play/Stop button with immersive Liquid Glass design
    private var playStopButton: some View {
        Button(action: togglePlayback) {
            ZStack {
                // Outer glow ring for depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isPlaying ? playButtonStopColor : playButtonPlayColor).opacity(0.3),
                                (isPlaying ? playButtonStopColor : playButtonPlayColor).opacity(0.0)
                            ],
                            center: .center,
                            startRadius: playButtonSize * 0.35,
                            endRadius: playButtonSize * 0.6
                        )
                    )
                    .frame(width: playButtonSize * 1.2, height: playButtonSize * 1.2)
                    .blur(radius: 20)
                    .opacity(pulseAnimation ? 0.6 : 0.3)
                    .animation(.easeInOut(duration: 0.25), value: isPlaying)

                // Main glass button layers
                ZStack {
                    // Base color layer with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isPlaying ? playButtonStopColor : playButtonPlayColor).opacity(0.9),
                                    (isPlaying ? playButtonStopColor : playButtonPlayColor)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .animation(.easeInOut(duration: 0.25), value: isPlaying)

                    // Glass refraction layer
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05),
                                    Color.clear,
                                    Color.black.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: playButtonSize * 0.4
                            )
                        )

                    // Ultra thin material for glass effect
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)

                    // Icon with enhanced depth
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: playButtonIconSize, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                        .shadow(color: (isPlaying ? playButtonStopColor : playButtonPlayColor).opacity(0.5), radius: 8, x: 0, y: 0)
                        .animation(.easeInOut(duration: 0.25), value: isPlaying)
                }
                .frame(width: playButtonSize, height: playButtonSize)
                .shadow(color: (isPlaying ? playButtonStopColor : playButtonPlayColor).opacity(0.3), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
                .animation(.easeInOut(duration: 0.25), value: isPlaying)
                .scaleEffect(pulseAnimation ? (isPlaying ? 1.03 : 1.02) : 1.0)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPlaying)
        .animation(
            pulseAnimation ?
            .easeInOut(duration: isPlaying ? 1.2 : 2.5).repeatForever(autoreverses: true) :
            .spring(response: 0.3, dampingFraction: 0.85),
            value: pulseAnimation
        )
        .onAppear {
            pulseAnimation = false
        }
        .onChange(of: isPlaying) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                self.pulseAnimation = newValue
            }
        }
    }
    
    
    // MARK: - Theme Components
    
    /// Theme toggle button with Liquid Glass enhancement
    private var themeToggleButton: some View {
        Button(action: cycleThemeMode) {
            ZStack {
                // Glass background layers
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                effectiveColorScheme == .dark ?
                                    Color.white.opacity(0.1) : Color.white.opacity(0.6),
                                effectiveColorScheme == .dark ?
                                    Color.white.opacity(0.05) : Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Material layer
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)

                // Specular highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: themeButtonSize * 0.4
                        )
                    )

                // Icon with depth
                Image(systemName: themeMode.iconName)
                    .font(.system(size: themeButtonIconSize, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.95),
                                Color.secondary.opacity(0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: effectiveColorScheme == .dark ?
                            .white.opacity(0.1) : .black.opacity(0.15),
                        radius: 1,
                        x: 0,
                        y: 0.5
                    )
            }
            .frame(width: themeButtonSize, height: themeButtonSize)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .scaleEffect(themeButtonOpacity == 1.0 ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(themeButtonOpacity)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: themeButtonOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: effectiveColorScheme)
        .accessibilityLabel("Theme: \(themeMode.displayName)")
        .accessibilityHint("Double tap to switch between light and dark themes")
        .onTapGesture {
            // Briefly brighten on tap with spring animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                themeButtonOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
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
    
    /// Liquid Glass inspired gradient background with depth and atmosphere
    private var backgroundForCurrentTheme: some View {
        ZStack {
            if effectiveColorScheme == .dark {
                // Dark mode: Rich gradient with depth for glass refraction
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.18),  // Slightly cooler top
                        Color(red: 0.10, green: 0.10, blue: 0.12),  // Deep middle
                        Color(red: 0.06, green: 0.06, blue: 0.08),  // Rich bottom
                        Color(red: 0.04, green: 0.04, blue: 0.06)   // Deepest shadow
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: Bright gradient with subtle warmth
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.99, blue: 1.00),  // Cool bright top
                        Color(red: 0.97, green: 0.97, blue: 0.98),  // Soft middle
                        Color(red: 0.94, green: 0.94, blue: 0.96),  // Deeper middle
                        Color(red: 0.90, green: 0.90, blue: 0.93)   // Gentle bottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Subtle atmospheric overlay for glass-like depth
            RadialGradient(
                colors: [
                    Color.white.opacity(effectiveColorScheme == .dark ? 0.02 : 0.04),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 600
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let baseHeight: CGFloat = 160
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
    
    
    /// Immersive Liquid Glass background for menu overlay with depth and refraction
    private var liquidGlassBackground: some View {
        ZStack {
            // Base translucent layer
            Rectangle()
                .fill(effectiveColorScheme == .dark ? .ultraThinMaterial : .thinMaterial)

            // Gradient overlay for depth and color refraction
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            effectiveColorScheme == .dark ?
                                Color.white.opacity(0.05) : Color.white.opacity(0.4),
                            effectiveColorScheme == .dark ?
                                Color.clear : Color.white.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Edge glow effect for glass borders
            Rectangle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(effectiveColorScheme == .dark ? 0.2 : 0.4),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .blur(radius: 0.5)
        }
    }
    
    /// Menu handle color with proper contrast
    private var menuHandleColor: Color {
        effectiveColorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.3)
    }
    
    
    /// Bottom menu button with Liquid Glass styling
    private var bottomMenuButton: some View {
        Button(action: toggleMenu) {
            VStack(spacing: 6) {
                ZStack {
                    // Glass handle with gradient and depth
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.secondary.opacity(0.8),
                                    Color.secondary.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 40, height: 5.5)

                    // Specular highlight on handle
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 40, height: 2.5)
                        .offset(y: -1.5)
                }
                .opacity(isMenuExpanded ? 0.6 : (handlePulseAnimation ? 1.0 : 0.85))
                .scaleEffect(isMenuExpanded ? 1.15 : (handlePulseAnimation ? 1.12 : 1.0))
                .shadow(
                    color: .black.opacity(effectiveColorScheme == .dark ? 0.3 : 0.15),
                    radius: 4,
                    x: 0,
                    y: 2
                )
                .shadow(
                    color: effectiveColorScheme == .dark ?
                        .white.opacity(0.05) : .white.opacity(0.2),
                    radius: 1,
                    x: 0,
                    y: -0.5
                )
                .animation(
                    handlePulseAnimation ?
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                    .spring(response: 0.4, dampingFraction: 0.73),
                    value: handlePulseAnimation
                )

                // Enhanced indicator text with glass effect
                if !isMenuExpanded {
                    Text("Sounds")
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.7),
                                    Color.gray.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: effectiveColorScheme == .dark ?
                                .black.opacity(0.3) : .white.opacity(0.5),
                            radius: 1,
                            x: 0,
                            y: 0.5
                        )
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isMenuExpanded)
        }
        .padding(.bottom, bottomMenuPadding)
        .onChange(of: isMenuExpanded) { _, expanded in
            // Stop pulse animation when menu is opened
            if expanded {
                withAnimation(.easeOut(duration: 0.3)) {
                    handlePulseAnimation = false
                }
            }
        }
    }
    
    /// Overlay menu that slides up from bottom with immersive glass effect
    private var menuOverlay: some View {
        VStack(spacing: 0) {
            Spacer()

            // Liquid Glass menu panel with enhanced depth
            VStack(spacing: 0) {
                Spacer()

                menuContent
                    .background(
                        ZStack {
                            liquidGlassBackground

                            // Additional specular highlight at top edge
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(effectiveColorScheme == .dark ? 0.08 : 0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 60)
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: -10)
                        .shadow(color: .black.opacity(0.1), radius: 50, x: 0, y: -20)
                    )
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isMenuExpanded)
    }
    
    /// Menu content with clean design and subtle Liquid Glass touches
    private var menuContent: some View {
        VStack(spacing: 0) {
            // Clean drag handle
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(.secondary)
                .frame(width: 36, height: 5)
                .opacity(0.6)
                .padding(.top, 16)
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isMenuExpanded = false
                    }
                }
            
            // Center the sound buttons vertically in remaining space
            Spacer()
            
            // Sound selector - clean layout
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
        .ignoresSafeArea(.container, edges: .horizontal)
    }
    
    /// Sound button with immersive Liquid Glass design
    private func soundButton(_ type: SoundType) -> some View {
        Button(action: { selectSound(type) }) {
            VStack(spacing: 12) {
                ZStack {
                    let isSelected = selectedSoundType == type

                    // Outer glow for selected state
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        soundBackgroundColor(for: type).opacity(0.4),
                                        soundBackgroundColor(for: type).opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: soundButtonSize * 0.3,
                                    endRadius: soundButtonSize * 0.7
                                )
                            )
                            .frame(width: soundButtonSize * 1.3, height: soundButtonSize * 1.3)
                            .blur(radius: 12)
                    }

                    // Main button glass layers
                    ZStack {
                        // Base layer
                        Circle()
                            .fill(
                                isSelected ?
                                LinearGradient(
                                    colors: [
                                        soundBackgroundColor(for: type).opacity(0.9),
                                        soundBackgroundColor(for: type)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        effectiveColorScheme == .dark ?
                                            Color.white.opacity(0.08) : Color.white.opacity(0.5),
                                        effectiveColorScheme == .dark ?
                                            Color.white.opacity(0.04) : Color.white.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // Material layer for glass effect
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(isSelected ? 0.2 : 0.6)

                        // Glass refraction
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isSelected ? 0.3 : 0.2),
                                        Color.clear,
                                        Color.black.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // Specular highlight
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(isSelected ? 0.4 : 0.3),
                                        Color.clear
                                    ],
                                    center: .init(x: 0.35, y: 0.35),
                                    startRadius: 0,
                                    endRadius: soundButtonSize * 0.35
                                )
                            )

                        // Icon with enhanced depth
                        Text(iconForSound(type))
                            .font(.system(size: soundButtonIconSize, weight: .semibold))
                            .foregroundStyle(
                                isSelected ?
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.95),
                                        Color.white.opacity(0.85)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color.primary.opacity(0.9),
                                        Color.primary.opacity(0.75)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(
                                color: isSelected ? .black.opacity(0.4) : .black.opacity(0.1),
                                radius: isSelected ? 2 : 1,
                                x: 0,
                                y: 1
                            )
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                    }
                    .frame(width: soundButtonSize, height: soundButtonSize)
                    .shadow(
                        color: isSelected ? soundBackgroundColor(for: type).opacity(0.3) : .black.opacity(0.05),
                        radius: isSelected ? 12 : 6,
                        x: 0,
                        y: isSelected ? 6 : 3
                    )
                }
                .frame(width: soundButtonSize, height: soundButtonSize)

                // Label with subtle glass effect
                Text(type.displayName)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(
                        selectedSoundType == type ?
                        .primary : .secondary
                    )
                    .shadow(
                        color: effectiveColorScheme == .dark ? .black.opacity(0.3) : .clear,
                        radius: 1,
                        x: 0,
                        y: 0.5
                    )
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedSoundType == type)
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
    
    /// Toggles between play and stop states with proper async handling
    private func togglePlayback() {
        guard !isTransitioning else { return }

        // Record user interaction for screen dimming
        recordUserInteraction()

        // Provide haptic feedback for physical button feel
        triggerHapticFeedback()

        isTransitioning = true

        // Update UI immediately for instant feedback (optimistic update)
        let targetState = !isPlaying
        withAnimation(.easeInOut(duration: 0.15)) {
            isPlaying = targetState
        }

        // Cancel any existing audio task
        audioTask?.cancel()

        // Use structured concurrency for audio operations
        audioTask = Task { @MainActor in
            if targetState {
                await startAudioQuick()
            } else {
                await stopAudioQuick()
            }
            isTransitioning = false
        }
    }
    
    /// Starts audio with quick response (no UI update - already done optimistically)
    @MainActor
    private func startAudioQuick() async {
        do {
            // Configure audio session for Now Playing / Control Center visibility
            let audioSession = AVAudioSession.sharedInstance()
            // Note: Removed .mixWithOthers to show in Now Playing/Control Center
            // Future: Make this toggleable in settings to allow mixing with other audio
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            // Initialize brown noise filter to prevent initial click
            if selectedSoundType == .brown && brownNoiseFilter == 0.0 {
                brownNoiseFilter = Float.random(in: -0.05...0.05)
            }

            // Use preloaded player for MP3 files
            if let player = preloadedPlayers[selectedSoundType] {
                await playMPAudio(player: player)
            } else {
                // Use audio engine for generated sounds
                try await playGeneratedAudio()
            }

        } catch {
            print("Audio start error: \(error.localizedDescription)")
            // Revert UI on error
            withAnimation(.easeInOut(duration: 0.15)) {
                isPlaying = false
            }
        }
    }

    /// Starts audio with proper async handling and error recovery (legacy method)
    @MainActor
    private func startAudio() async {
        do {
            // Configure audio session for Now Playing / Control Center visibility
            let audioSession = AVAudioSession.sharedInstance()
            // Note: Removed .mixWithOthers to show in Now Playing/Control Center
            // Future: Make this toggleable in settings to allow mixing with other audio
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            // Initialize brown noise filter to prevent initial click
            if selectedSoundType == .brown && brownNoiseFilter == 0.0 {
                brownNoiseFilter = Float.random(in: -0.05...0.05)
            }

            // Use preloaded player for MP3 files
            if let player = preloadedPlayers[selectedSoundType] {
                await playMPAudio(player: player)
            } else {
                // Use audio engine for generated sounds
                try await playGeneratedAudio()
            }

            // Update UI state
            withAnimation(.easeInOut(duration: 0.2)) {
                isPlaying = true
            }

        } catch {
            print("Audio start error: \(error.localizedDescription)")
            isPlaying = false
        }
    }
    
    /// Plays MP3 audio using preloaded AVAudioPlayer with async handling
    private func playMPAudio(player: AVAudioPlayer) async {
        // Stop any current audio first
        await stopAudioSilently()
        
        // Configure and start the player
        currentAudioPlayer = player
        currentAudioPlayer?.numberOfLoops = -1 // Infinite loop
        currentAudioPlayer?.currentTime = 0
        currentAudioPlayer?.play()
    }
    
    /// Plays generated audio using AVAudioEngine with async handling
    private func playGeneratedAudio() async throws {
        // Stop any current audio first
        await stopAudioSilently()
        
        let engine = AVAudioEngine()
        let noiseNode = createWhiteNoiseNode()
        let lowPassFilter = createLowPassFilter()
        
        setupAudioChain(engine: engine, noiseNode: noiseNode, filter: lowPassFilter)
        
        try engine.start()
        audioEngine = engine
        whiteNoiseNode = noiseNode
    }
    
    /// Creates optimized audio source node for noise generation (Performance Critical)
    private func createWhiteNoiseNode() -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for buffer in bufferListPointer {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }

                let finalGain: Float = 0.8
                let frameCountInt = Int(frameCount)
                let soundType = self.selectedSoundType

                switch soundType {
                case .white:
                    // Ultra-optimized white noise - use direct pointer writes
                    var rng = SystemRandomNumberGenerator()
                    for frame in 0..<frameCountInt {
                        // Avoid closure overhead by inlining random generation
                        let randomValue = Float(rng.next()) / Float(UInt64.max) // 0 to 1
                        data[frame] = (randomValue * 0.8 - 0.4) * finalGain // Scale to -0.4...0.4
                    }

                case .brown:
                    // Optimized brown noise - minimize operations per sample
                    let filterCoeff: Float = 0.02
                    let gainComp: Float = 3.5
                    var filter = self.brownNoiseFilter
                    var rng = SystemRandomNumberGenerator()

                    for frame in 0..<frameCountInt {
                        let randomValue = Float(rng.next()) / Float(UInt64.max)
                        let noise = randomValue * 0.6 - 0.3 // Scale to -0.3...0.3
                        filter += filterCoeff * (noise - filter)
                        // Use clamp instead of min/max for better performance
                        let sample = filter * gainComp
                        data[frame] = (sample < -1.0 ? -1.0 : (sample > 1.0 ? 1.0 : sample)) * finalGain
                    }

                    self.brownNoiseFilter = filter

                default:
                    // Use memset for faster zeroing
                    memset(data, 0, frameCountInt * MemoryLayout<Float>.stride)
                }
            }
            return noErr
        }
    }
    
    /// Creates optimized low-pass filter to reduce harsh frequencies
    private func createLowPassFilter() -> AVAudioUnitEQ {
        let filter = AVAudioUnitEQ(numberOfBands: 1)
        filter.bands[0].filterType = .lowPass
        
        // Adaptive filter frequency based on sound type
        switch selectedSoundType {
        case .white:
            filter.bands[0].frequency = 8000  // Allow more brightness for white noise
        case .brown:
            filter.bands[0].frequency = 4000  // Warmer for brown noise
        default:
            filter.bands[0].frequency = 6000  // Default
        }
        
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

    /// Stops audio quickly (no UI update - already done optimistically)
    @MainActor
    private func stopAudioQuick() async {
        await stopAudioSilently()
    }

    /// Stops audio with proper async handling (legacy method)
    @MainActor
    private func stopAudio() async {
        // Update UI state
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaying = false
        }

        await stopAudioSilently()
    }
    
    /// Stops audio without updating UI state (for internal use)
    private func stopAudioSilently() async {
        // Stop current audio player
        if let player = currentAudioPlayer {
            player.stop()
            currentAudioPlayer = nil
        }
        
        // Stop audio engine
        if let engine = audioEngine {
            engine.stop()
            audioEngine = nil
            whiteNoiseNode = nil
        }
    }

    // MARK: - Resource Cleanup
    
    /// Comprehensive cleanup of all audio resources
    private func cleanupAllResources() {
        // Cancel all tasks
        audioTask?.cancel()
        screenDimTask?.cancel()
        
        // Stop all audio
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        
        audioEngine?.stop()
        audioEngine = nil
        whiteNoiseNode = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Audio session deactivation error: \(error.localizedDescription)")
        }
        
        // Re-enable screen timeout
        UIApplication.shared.isIdleTimerDisabled = false
    }

    
    // MARK: - Theme Actions
    
    /// Cycles through system, light, and dark theme modes
    private func cycleThemeMode() {
        // Record user interaction for screen dimming
        recordUserInteraction()

        triggerLightHapticFeedback()

        // Simple toggle between light and dark
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
    
    /// Selects sound type with instant UI feedback and async audio handling
    private func selectSound(_ type: SoundType) {
        // Only prevent if same sound type
        guard selectedSoundType != type else { return }
        
        // Record user interaction for screen dimming
        recordUserInteraction()
        
        triggerLightHapticFeedback()
        
        // Update UI immediately for instant feedback
        selectedSoundType = type
        
        // Update Now Playing info with new sound type
        updateNowPlayingInfo()
        
        // If audio is playing, restart with new sound using async
        if isPlaying {
            // Cancel any existing audio task
            audioTask?.cancel()
            
            audioTask = Task { @MainActor in
                await stopAudioSilently()
                await startAudio()
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
    
    // MARK: - Audio Preloading
    
    /// Efficiently preloads MP3 audio files to prevent hitches
    private func preloadAudioFiles() {
        let audioFiles: [(SoundType, String, Float)] = [
            (.fire, "fire", 0.8),
            (.rain, "rain", 0.4),
            (.birds, "birdsounds", 0.6)
        ]
        
        for (soundType, filename, volume) in audioFiles {
            guard let path = Bundle.main.path(forResource: filename, ofType: "mp3") else {
                print("Audio file not found: \(filename).mp3")
                continue
            }
            
            let url = URL(fileURLWithPath: path)
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.volume = volume
                player.enableRate = false
                preloadedPlayers[soundType] = player
            } catch {
                print("Failed to preload \(filename) audio: \(error.localizedDescription)")
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
        print("DEBUG: updateScreenDimming called with isPlaying: \(isPlaying)")
        if isPlaying {
            // When audio starts, prevent immediate dimming but allow delayed dimming
            print("DEBUG: Audio started - resetting screen dim timer")
            resetScreenDimTimer()
        } else {
            // When audio stops, return to normal system dimming
            print("DEBUG: Audio stopped - returning to normal screen dimming")
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
                print("DEBUG: Screen timeout enabled immediately (audio stopped)")
            }
        }
    }
    
    /// Records user interaction and resets screen dim timer
    private func recordUserInteraction() {
        lastUserInteraction = Date()
        print("DEBUG: User interaction recorded, isPlaying: \(isPlaying)")
        
        // If audio is playing, reset the dimming timer
        if isPlaying {
            print("DEBUG: Audio is playing - resetting screen dim timer due to user interaction")
            resetScreenDimTimer()
        }
    }
    
    /// Resets screen dim timer using structured concurrency
    private func resetScreenDimTimer() {
        // Cancel existing task
        screenDimTask?.cancel()
        
        // Prevent immediate dimming
        UIApplication.shared.isIdleTimerDisabled = true
        print("DEBUG: Screen timeout disabled - preventing dimming for 30 seconds")
        
        // Use structured concurrency for reliable execution
        screenDimTask = Task {
            do {
                try await Task.sleep(for: .seconds(30))
                await MainActor.run {
                    if !Task.isCancelled {
                        UIApplication.shared.isIdleTimerDisabled = false
                        print("DEBUG: Screen timeout re-enabled - allowing system dimming")
                    }
                }
            } catch {
                // Task was cancelled, which is expected behavior
            }
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

        // Enable next track command (cycle forward through sounds)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            self.cycleToNextSound()
            return .success
        }

        // Enable previous track command (cycle backward through sounds)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            self.cycleToPreviousSound()
            return .success
        }

        // Disable skip forward/backward (not applicable for continuous sounds)
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        // Disable seek commands (not applicable for continuous sounds)
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }

    /// Cycles to the next sound in the list
    private func cycleToNextSound() {
        let allSounds = SoundType.allCases
        guard let currentIndex = allSounds.firstIndex(of: selectedSoundType) else { return }

        let nextIndex = (currentIndex + 1) % allSounds.count
        let nextSound = allSounds[nextIndex]

        selectSound(nextSound)
    }

    /// Cycles to the previous sound in the list
    private func cycleToPreviousSound() {
        let allSounds = SoundType.allCases
        guard let currentIndex = allSounds.firstIndex(of: selectedSoundType) else { return }

        let previousIndex = (currentIndex - 1 + allSounds.count) % allSounds.count
        let previousSound = allSounds[previousIndex]

        selectSound(previousSound)
    }
    
    /// Sets up listener for Siri intent notifications
    private func setupSiriIntentListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PlaySoundFromSiri"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let soundTypeString = userInfo["soundType"] as? String else { return }

            // Map sound type string to SoundType enum
            let soundType: SoundType
            switch soundTypeString.lowercased() {
            case "white noise", "white":
                soundType = .white
            case "brown noise", "brown":
                soundType = .brown
            case "fire":
                soundType = .fire
            case "rain":
                soundType = .rain
            case "birds", "bird sounds":
                soundType = .birds
            default:
                return
            }

            // Select the sound and start playing
            self.selectSound(soundType)
            if !self.isPlaying {
                self.togglePlayback()
            }
        }
    }

    /// Updates Now Playing info for Control Center and lock screen
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(selectedSoundType.displayName) Noise"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "No-BS White Noise"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        // Set album artwork to app logo
        if let logoImage = UIImage(named: "logo") {
            let artwork = MPMediaItemArtwork(boundsSize: logoImage.size) { _ in
                return logoImage
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
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
