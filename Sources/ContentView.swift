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
    // MARK: - Audio
    /// All audio behavior lives here; the view is presentation only.
    @State private var audio = AudioEngine()

    // MARK: - UI State
    @State private var pulseAnimation = false
    @State private var handlePulseAnimation = false
    @AppStorage("themeMode") private var themeMode: ThemeMode = .light
    @State private var themeButtonOpacity: Double = 0.6
    @State private var isMenuExpanded = false
    @State private var lastUserInteraction: Date = Date()
    @State private var screenDimTask: Task<Void, Error>?

    // MARK: - Environment
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                VStack(spacing: 20) {
                    playStopButton
                    sleepTimerCountdown
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

            #if DEBUG
            applyScreenshotStateIfNeeded()
            #endif

            // One-time audio setup (preload, remote commands, observers)
            audio.start()

            // Initialize screen management
            setupScreenManagement()

            // Start handle pulse animation after a short delay to draw attention
            // (skipped entirely when Reduce Motion is on)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard !reduceMotion else { return }
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
        .onChange(of: audio.isPlaying) { _, newValue in
            // Update screen dimming behavior based on playback state
            updateScreenDimming(isPlaying: newValue)

            // Update Control Center info
            audio.updateNowPlayingInfo()
        }
        .onDisappear {
            // Clean up all resources when view disappears
            cleanupAllResources()
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
    
    /// Play/Stop button — the hero control, rendered in genuine Liquid Glass on iOS 26.
    private var playStopButton: some View {
        let stateColor = audio.isPlaying ? playButtonStopColor : playButtonPlayColor
        return Button(action: togglePlayback) {
            ZStack {
                // Soft colored glow so the hero reads on both light and dark backgrounds
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [stateColor.opacity(0.35), stateColor.opacity(0.0)],
                            center: .center,
                            startRadius: playButtonSize * 0.35,
                            endRadius: playButtonSize * 0.68
                        )
                    )
                    .frame(width: playButtonSize * 1.3, height: playButtonSize * 1.3)
                    .blur(radius: 24)
                    .opacity(pulseAnimation ? 0.75 : 0.45)
                    .animation(.easeInOut(duration: 0.25), value: audio.isPlaying)

                playButtonSurface(stateColor: stateColor)
                    .shadow(color: stateColor.opacity(0.35), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 16)
                    .scaleEffect(pulseAnimation ? (audio.isPlaying ? 1.03 : 1.02) : 1.0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audio.isPlaying ? "Stop" : "Play")
        .accessibilityHint(audio.isPlaying ? "Stops the sound" : "Plays \(audio.selectedSound.displayName) noise")
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: audio.isPlaying)
        .animation(
            pulseAnimation ?
            .easeInOut(duration: audio.isPlaying ? 1.2 : 2.5).repeatForever(autoreverses: true) :
            .spring(response: 0.3, dampingFraction: 0.85),
            value: pulseAnimation
        )
        .onAppear {
            pulseAnimation = false
        }
        .onChange(of: audio.isPlaying) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                // Respect Reduce Motion: skip the endless pulse
                self.pulseAnimation = newValue && !reduceMotion
            }
        }
    }

    /// The circular hero surface: a tinted, interactive Liquid Glass circle on iOS 26,
    /// with a layered gradient fallback on earlier systems.
    @ViewBuilder
    private func playButtonSurface(stateColor: Color) -> some View {
        let icon = Image(systemName: audio.isPlaying ? "stop.fill" : "play.fill")
            .font(.system(size: playButtonIconSize, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)

        if #available(iOS 26.0, *) {
            ZStack {
                Circle().fill(stateColor.opacity(0.55))
                icon
            }
            .frame(width: playButtonSize, height: playButtonSize)
            .glassEffect(.regular.tint(stateColor).interactive(), in: Circle())
        } else {
            ZStack {
                Circle().fill(stateColor.gradient)
                Circle().fill(.ultraThinMaterial).opacity(0.25)
                icon
            }
            .frame(width: playButtonSize, height: playButtonSize)
        }
    }
    
    
    /// Live countdown capsule shown under the play button while a sleep timer is armed.
    /// Occupies a fixed-height slot so the play button never shifts.
    private var sleepTimerCountdown: some View {
        Group {
            if let end = audio.sleepTimerEndDate {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .glassCapsule(interactive: false)  // status readout, not a control
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .accessibilityLabel("Sleep timer running")
            }
        }
        .frame(height: 36)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audio.sleepTimerEndDate != nil)
    }

    // MARK: - Theme Components

    /// Theme toggle button with Liquid Glass enhancement
    private var themeToggleButton: some View {
        Button(action: cycleThemeMode) {
            themeToggleSurface
                .scaleEffect(themeButtonOpacity == 1.0 ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(themeButtonOpacity)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: themeButtonOpacity)
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: effectiveColorScheme)
        .accessibilityLabel("Theme: \(themeMode.displayName)")
        .accessibilityHint("Double tap to switch between light and dark themes")
    }

    /// Circular theme-toggle surface using genuine Liquid Glass on iOS 26.
    @ViewBuilder
    private var themeToggleSurface: some View {
        Image(systemName: themeMode.iconName)
            .font(.system(size: themeButtonIconSize, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: themeButtonSize, height: themeButtonSize)
            .glassCircle()
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
        let baseHeight: CGFloat = 296  // sounds + volume + sleep-timer rows
        return baseHeight * scalingFactor
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
                    .glassPanel(cornerRadius: 28)
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: -10)
                    .shadow(color: .black.opacity(0.1), radius: 50, x: 0, y: -20)
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
            
            // Sound selector — grouped so the glass circles blend and morph together
            glassGroup {
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
            }

            Spacer()

            // Master volume
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { audio.masterVolume },
                        set: { audio.masterVolume = $0 }  // engine applies live
                    ),
                    in: 0...1
                )
                .tint(.secondary)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, soundMenuHorizontalPadding + 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int(audio.masterVolume * 100)) percent")

            Spacer()

            // Sleep timer selector
            VStack(spacing: 10) {
                Text("SLEEP TIMER")
                    .font(.system(.caption2, design: .default, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(1.2)

                // Chips stay crisp/separate — no GlassEffectContainer here, so
                // neighbouring glass capsules don't merge into blobs.
                HStack(spacing: 8) {
                    sleepTimerChip(nil)
                    ForEach(AudioEngine.sleepTimerOptions, id: \.self) { minutes in
                        sleepTimerChip(minutes)
                    }
                }
            }
            .padding(.horizontal, soundMenuHorizontalPadding)

            // Equal space below to center the content
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: menuOverlayHeight)
        .ignoresSafeArea(.container, edges: .horizontal)
        // The drawer is a compact control cluster with no horizontal headroom —
        // even xxxLarge overflows the 7-chip timer row on a 440pt screen. Pin it
        // at the default size (standard for toolbars/drawers); every control has
        // an accessibilityLabel so VoiceOver remains fully usable, and the main
        // screen still scales with Dynamic Type.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }
    
    /// Sound button — a genuine Liquid Glass circle, tinted when selected (iOS 26).
    private func soundButton(_ type: SoundType) -> some View {
        let isSelected = audio.selectedSound == type
        let tint = soundBackgroundColor(for: type)
        return Button(action: { selectSound(type) }) {
            VStack(spacing: 12) {
                Text(iconForSound(type))
                    .font(.system(size: soundButtonIconSize, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .frame(width: soundButtonSize, height: soundButtonSize)
                    .glassCircle(tint: isSelected ? tint : nil)
                    .shadow(
                        color: isSelected ? tint.opacity(0.35) : .black.opacity(0.05),
                        radius: isSelected ? 12 : 5,
                        x: 0,
                        y: isSelected ? 6 : 3
                    )

                Text(type.displayName)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSelected)
        .accessibilityLabel("\(type.displayName) sound")
        .accessibilityHint("Select \(type.displayName.lowercased()) sound")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    /// Sleep timer chip — a compact Liquid Glass capsule. `nil` means "Off".
    private func sleepTimerChip(_ minutes: Int?) -> some View {
        let isSelected = audio.sleepTimerMinutes == minutes
        let label = minutes.map { "\($0)m" } ?? "Off"
        return Button(action: { setSleepTimer(minutes) }) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .glassCapsule(tint: isSelected ? .indigo : nil)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
        .accessibilityLabel(minutes.map { "Sleep timer \($0) minutes" } ?? "Sleep timer off")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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

    /// Groups nearby Liquid Glass shapes so they blend and morph together (iOS 26+).
    /// On earlier systems the content is returned unwrapped.
    @ViewBuilder
    private func glassGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                content()
            }
        } else {
            content()
        }
    }

    #if DEBUG
    /// Applies deterministic UI state from the launch environment so App Store
    /// screenshots can be captured for each state. Compiled only in DEBUG builds.
    private func applyScreenshotStateIfNeeded() {
        let env = ProcessInfo.processInfo.environment
        if let theme = env["UITEST_THEME"] {
            themeMode = (theme == "dark") ? .dark : .light
        }
        if let sound = env["UITEST_SOUND"], let type = SoundType(rawValue: sound) {
            audio.selectedSound = type
        }
        if env["UITEST_MENU"] == "1" {
            isMenuExpanded = true
        }
        let playing = env["UITEST_PLAYING"] == "1" ? true : nil
        let timerMinutes = env["UITEST_TIMER"].flatMap(Int.init)
        if playing != nil || timerMinutes != nil {
            audio.applyScreenshotState(playing: playing, timerMinutes: timerMinutes)
        }
    }
    #endif

    // MARK: - Audio Control (delegated to AudioEngine)

    /// Toggles playback: view concerns here (haptics, screen dimming, animation),
    /// audio concerns in the engine.
    private func togglePlayback() {
        guard !audio.isTransitioning else { return }

        recordUserInteraction()
        triggerHapticFeedback()

        withAnimation(.easeInOut(duration: 0.15)) {
            _ = audio.togglePlayback()
        }
    }
    
    // MARK: - Resource Cleanup

    /// Cleans up audio (via the engine) and view-owned resources
    private func cleanupAllResources() {
        screenDimTask?.cancel()
        audio.cleanup()

        // Re-enable screen timeout
        UIApplication.shared.isIdleTimerDisabled = false
    }

    
    // MARK: - Theme Actions
    
    /// Toggles between light and dark theme modes
    private func cycleThemeMode() {
        // Record user interaction for screen dimming
        recordUserInteraction()

        triggerLightHapticFeedback()

        // Briefly brighten the toggle on tap for tactile feedback
        withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
            themeButtonOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                themeButtonOpacity = 0.6
            }
        }

        // Toggle between light and dark
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
    
    /// Selects a sound: view concerns here, audio handled by the engine
    private func selectSound(_ type: SoundType) {
        guard audio.selectedSound != type else { return }
        recordUserInteraction()
        triggerLightHapticFeedback()
        audio.selectSound(type)
    }

    /// Arms or clears the sleep timer via the engine
    private func setSleepTimer(_ minutes: Int?) {
        recordUserInteraction()
        triggerLightHapticFeedback()
        audio.setSleepTimer(minutes)
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
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
    /// Records user interaction and resets screen dim timer
    private func recordUserInteraction() {
        lastUserInteraction = Date()

        // If audio is playing, reset the dimming timer
        if audio.isPlaying {
            resetScreenDimTimer()
        }
    }
    
    /// Resets screen dim timer using structured concurrency
    private func resetScreenDimTimer() {
        // Cancel existing task
        screenDimTask?.cancel()
        
        // Prevent immediate dimming
        UIApplication.shared.isIdleTimerDisabled = true

        // Use structured concurrency for reliable execution
        screenDimTask = Task {
            do {
                try await Task.sleep(for: .seconds(30))
                await MainActor.run {
                    if !Task.isCancelled {
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                }
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
    }
    
}

// MARK: - Liquid Glass Helpers

/// Builds a configured `Glass` value. Kept separate so call sites stay readable.
@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint {
        glass = glass.tint(tint)
    }
    if interactive {
        glass = glass.interactive()
    }
    return glass
}

private extension View {
    /// Applies a genuine Liquid Glass effect clipped to a circle on iOS 26+,
    /// falling back to a translucent material on earlier systems.
    @ViewBuilder
    func glassCircle(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(makeGlass(tint: tint, interactive: interactive), in: Circle())
        } else {
            background(.ultraThinMaterial, in: Circle())
        }
    }

    /// Applies a genuine Liquid Glass effect clipped to a capsule on iOS 26+,
    /// falling back to a translucent material on earlier systems.
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(makeGlass(tint: tint, interactive: interactive), in: Capsule())
        } else {
            background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// Applies a genuine Liquid Glass effect clipped to a rounded rectangle on iOS 26+,
    /// falling back to a translucent material on earlier systems.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
