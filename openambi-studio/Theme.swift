import SwiftUI

// MARK: - Sound Color System (Enhanced)
struct SoundColor {
    // Nature sounds - vibrant, organic colors with gradients
    static let rain = Color(red: 0.3, green: 0.72, blue: 1.0) // #4DB8FF
    static let rainDark = Color(red: 0.12, green: 0.53, blue: 0.9) // #1E88E5
    static let rainGradient = LinearGradient(
        colors: [rain, rainDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let ocean = Color(red: 0.18, green: 0.6, blue: 1.0) // #2E9AFE
    static let oceanDark = Color(red: 0.08, green: 0.4, blue: 0.75) // #1565C0
    static let oceanGradient = LinearGradient(
        colors: [ocean, oceanDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let birds = Color(red: 0.4, green: 0.73, blue: 0.42) // #66BB6A
    static let birdsDark = Color(red: 0.22, green: 0.56, blue: 0.24) // #388E3C
    static let birdsGradient = LinearGradient(
        colors: [birds, birdsDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let wind = Color(red: 0.5, green: 0.7, blue: 0.5) // Forest green
    static let windDark = Color(red: 0.3, green: 0.5, blue: 0.3)
    static let windGradient = LinearGradient(
        colors: [wind, windDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let thunder = Color(red: 0.58, green: 0.46, blue: 0.8) // #9575CD
    static let thunderDark = Color(red: 0.37, green: 0.21, blue: 0.69) // #5E35B1
    static let thunderGradient = LinearGradient(
        colors: [thunder, thunderDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let river = Color(red: 0.3, green: 0.82, blue: 0.88) // #4DD0E1
    static let riverDark = Color(red: 0.0, green: 0.59, blue: 0.65) // #0097A7
    static let riverGradient = LinearGradient(
        colors: [river, riverDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Indoor sounds - warm, cozy colors
    static let fireplace = Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35
    static let fireplaceDark = Color(red: 0.9, green: 0.22, blue: 0.21) // #E53935
    static let fireplaceGradient = LinearGradient(
        colors: [fireplace, fireplaceDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let tibetanBowl = Color(red: 0.96, green: 0.56, blue: 0.69) // #F48FB1
    static let tibetanBowlDark = Color(red: 0.76, green: 0.09, blue: 0.36) // #C2185B
    static let tibetanBowlGradient = LinearGradient(
        colors: [tibetanBowl, tibetanBowlDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Additional sounds
    static let cafe = Color(red: 0.63, green: 0.53, blue: 0.47) // #A1887F
    static let cafeDark = Color(red: 0.36, green: 0.25, blue: 0.22) // #5D4037
    static let cafeGradient = LinearGradient(
        colors: [cafe, cafeDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let fan = Color(red: 0.56, green: 0.64, blue: 0.68) // #90A4AE
    static let fanDark = Color(red: 0.33, green: 0.43, blue: 0.48) // #546E7A
    static let fanGradient = LinearGradient(
        colors: [fan, fanDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let meditation = Color(red: 0.73, green: 0.41, blue: 0.78) // #BA68C8
    static let meditationDark = Color(red: 0.48, green: 0.12, blue: 0.64) // #7B1FA2
    static let meditationGradient = LinearGradient(
        colors: [meditation, meditationDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Helper function to get color by track name
    static func colorForTrack(_ name: String) -> Color {
        let nameLower = name.lowercased()
        if nameLower.contains("rain") { return rain }
        if nameLower.contains("ocean") || nameLower.contains("wave") { return ocean }
        if nameLower.contains("bird") { return birds }
        if nameLower.contains("wind") { return wind }
        if nameLower.contains("thunder") { return thunder }
        if nameLower.contains("river") { return river }
        if nameLower.contains("fire") { return fireplace }
        if nameLower.contains("bowl") || nameLower.contains("tibetan") { return tibetanBowl }
        if nameLower.contains("cafe") || nameLower.contains("coffee") { return cafe }
        if nameLower.contains("fan") { return fan }
        if nameLower.contains("meditation") || nameLower.contains("zen") { return meditation }
        return Color.white.opacity(0.3) // Default
    }
    
    // Helper function to get gradient by track name
    static func gradientForTrack(_ name: String) -> LinearGradient {
        let nameLower = name.lowercased()
        if nameLower.contains("rain") { return rainGradient }
        if nameLower.contains("ocean") || nameLower.contains("wave") { return oceanGradient }
        if nameLower.contains("bird") { return birdsGradient }
        if nameLower.contains("wind") { return windGradient }
        if nameLower.contains("thunder") { return thunderGradient }
        if nameLower.contains("river") { return riverGradient }
        if nameLower.contains("fire") { return fireplaceGradient }
        if nameLower.contains("bowl") || nameLower.contains("tibetan") { return tibetanBowlGradient }
        if nameLower.contains("cafe") || nameLower.contains("coffee") { return cafeGradient }
        if nameLower.contains("fan") { return fanGradient }
        if nameLower.contains("meditation") || nameLower.contains("zen") { return meditationGradient }
        return LinearGradient(
            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Liquid Glass View Modifier (Enhanced for Premium Feel)
struct LiquidGlass: ViewModifier {
    var intensity: Double = 1.0 // 0.0 to 1.0 for blur/opacity intensity
    var cornerRadius: CGFloat = 20
    var blurIntensity: BlurIntensity = .light
    var opacityLevel: OpacityLevel = .content
    
    enum BlurIntensity {
        case ultraLight // 8pt blur (increased)
        case light      // 15pt blur (increased)
        case medium     // 25pt blur (increased)
        case heavy      // 40pt blur (increased)
        
        var value: CGFloat {
            switch self {
            case .ultraLight: return 8
            case .light: return 15
            case .medium: return 25
            case .heavy: return 40
            }
        }
    }
    
    enum OpacityLevel {
        case background  // 0.25-0.45 (more transparent)
        case content     // 0.55-0.75 (more transparent)
        case controls    // 0.75-0.92 (more transparent)
        case text        // 1.0
        
        var range: (min: Double, max: Double) {
            switch self {
            case .background: return (0.25, 0.45)
            case .content: return (0.55, 0.75)
            case .controls: return (0.75, 0.92)
            case .text: return (1.0, 1.0)
            }
        }
    }
    
    func body(content: Content) -> some View {
        let opacity = opacityLevel.range.min + (opacityLevel.range.max - opacityLevel.range.min) * intensity
        
        content
            .background {
                ZStack {
                    // Base material (native blur is built-in) - enhanced with multiple layers
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)
                    
                    // Secondary material layer for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                        .opacity(opacity * 0.3)
                    
                    // Additional blur layer for depth (enhanced)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.02))
                        .blur(radius: blurIntensity.value * 0.6 * intensity)
                    
                    // Enhanced gradient overlay for depth and translucency
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15 * intensity),
                            Color.white.opacity(0.08 * intensity),
                            Color.white.opacity(0.03 * intensity),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    
                    // Radial highlight for premium glass effect
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.12 * intensity),
                            Color.white.opacity(0.04 * intensity),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: cornerRadius * 3
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    
                    // Enhanced border with gradient (more refined)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4 * intensity),
                                    Color.white.opacity(0.2 * intensity),
                                    Color.white.opacity(0.15 * intensity),
                                    Color.white.opacity(0.2 * intensity),
                                    Color.white.opacity(0.4 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func liquidGlass(intensity: Double = 1.0, cornerRadius: CGFloat = 20, blurIntensity: LiquidGlass.BlurIntensity = .light, opacityLevel: LiquidGlass.OpacityLevel = .content) -> some View {
        modifier(LiquidGlass(intensity: intensity, cornerRadius: cornerRadius, blurIntensity: blurIntensity, opacityLevel: opacityLevel))
    }
}

// MARK: - Enhanced Glass Card Modifier (Multi-Layer System)
struct GlassCard: ViewModifier {
    let color: Color
    let intensity: Double // 0.0 to 1.0 for volume-based intensity
    let isActive: Bool
    let cornerRadius: CGFloat
    
    init(color: Color, intensity: Double = 0.5, isActive: Bool = false, cornerRadius: CGFloat = 24) {
        self.color = color
        self.intensity = intensity
        self.isActive = isActive
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        // Pre-compute gradients to simplify expression
        let colorTintGradient = LinearGradient(
            colors: [
                color.opacity(0.3 * intensity),
                color.opacity(0.15 * intensity),
                color.opacity(0.05 * intensity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        let noiseGradient = RadialGradient(
            colors: [
                Color.white.opacity(0.05),
                Color.clear,
                Color.black.opacity(0.02)
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: cornerRadius * 2
        )
        
        let activeBorderColors = [
            color.opacity(0.9),
            color.opacity(0.6),
            color.opacity(0.4),
            color.opacity(0.6),
            color.opacity(0.9)
        ]
        
        let inactiveBorderColors = [
            Color.white.opacity(0.15),
            Color.white.opacity(0.08),
            Color.white.opacity(0.05),
            Color.white.opacity(0.08),
            Color.white.opacity(0.15)
        ]
        
        let borderGradient = LinearGradient(
            colors: isActive ? activeBorderColors : inactiveBorderColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        let highlightGradient = LinearGradient(
            colors: [
                Color.white.opacity(isActive ? 0.15 : 0.05),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .center
        )
        
        // Pre-compute shadow values
        let shadowColor = isActive ? color.opacity(0.5) : Color.black.opacity(0.25)
        let shadowRadius = isActive ? 25.0 : 12.0
        let shadowY = isActive ? 12.0 : 6.0
        let glowColor = isActive ? color.opacity(0.2) : Color.clear
        let glowRadius = isActive ? 40.0 : 0.0
        let glowY = isActive ? 20.0 : 0.0
        
        return content
            .background {
                ZStack {
                    // Layer 1: Base glass material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(isActive ? 0.95 : 0.85)
                    
                    // Layer 2: Color-tinted blur overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(colorTintGradient)
                        .blur(radius: 2)
                    
                    // Layer 3: Subtle noise texture
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(noiseGradient)
                    
                    // Layer 4: Animated border glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderGradient, lineWidth: isActive ? 3.0 : 1.5)
                    
                    // Layer 5: Inner highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(highlightGradient)
                }
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .shadow(color: glowColor, radius: glowRadius, x: 0, y: glowY)
    }
}

extension View {
    func glassCard(color: Color, intensity: Double = 0.5, isActive: Bool = false) -> some View {
        modifier(GlassCard(color: color, intensity: intensity, isActive: isActive))
    }
}

// MARK: - Typography System (Premium Liquid Glass - Inspired by Calm/Headspace)
struct AppTypography {
    // Font sizes (premium, generous sizing for readability)
    static let h1: CGFloat = 40 // Central Hub (increased for premium feel)
    static let h2: CGFloat = 22 // Orb Labels (increased)
    static let h3: CGFloat = 20 // Dock Items (increased)
    static let body: CGFloat = 17 // Volume % (increased for readability)
    static let caption: CGFloat = 14 // Hints (increased)
    
    // Premium sizes for Liquid Glass
    static let display: CGFloat = 52 // Large display text (increased)
    static let title: CGFloat = 32 // Section titles (increased)
    static let subheadline: CGFloat = 16 // Subheadings (increased)
    
    // Font weights
    static let h1Weight: Font.Weight = .bold
    static let h2Weight: Font.Weight = .semibold
    static let h3Weight: Font.Weight = .medium
    static let bodyWeight: Font.Weight = .regular
    static let captionWeight: Font.Weight = .regular
    static let displayWeight: Font.Weight = .bold
    static let titleWeight: Font.Weight = .bold
    
    // Line heights (improved for readability)
    static let h1LineHeight: CGFloat = 1.2
    static let h2LineHeight: CGFloat = 1.3
    static let bodyLineHeight: CGFloat = 1.5
    static let captionLineHeight: CGFloat = 1.4
    
    // Letter spacing
    static let h1Tracking: CGFloat = -0.5
    static let h2Tracking: CGFloat = 0
    static let h3Tracking: CGFloat = 1.5 // Uppercase labels
    static let bodyTracking: CGFloat = 0
    static let captionTracking: CGFloat = 0.5
    
    // Helper functions
    static func h1(_ text: String) -> Text {
        Text(text)
            .font(.system(size: h1, weight: h1Weight, design: .rounded))
            .kerning(h1Tracking)
    }
    
    static func h2(_ text: String) -> Text {
        Text(text)
            .font(.system(size: h2, weight: h2Weight, design: .rounded))
            .kerning(h2Tracking)
    }
    
    static func h3(_ text: String) -> Text {
        Text(text.uppercased())
            .font(.system(size: h3, weight: h3Weight, design: .rounded))
            .kerning(h3Tracking)
    }
    
    static func body(_ text: String) -> Text {
        Text(text)
            .font(.system(size: body, weight: bodyWeight, design: .default))
            .kerning(bodyTracking)
    }
    
    static func caption(_ text: String) -> Text {
        Text(text)
            .font(.system(size: caption, weight: captionWeight, design: .default))
            .kerning(captionTracking)
    }
    
    // Monospaced for numbers (volume percentages)
    static func volume(_ value: Int) -> Text {
        Text("\(value)%")
            .font(.system(size: body, weight: bodyWeight, design: .monospaced))
    }
    
    // New helper functions for Liquid Glass
    static func display(_ text: String) -> some View {
        Text(text)
            .font(.system(size: display, weight: displayWeight, design: .rounded))
            .lineSpacing(display * (h1LineHeight - 1))
    }
    
    static func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: title, weight: titleWeight, design: .rounded))
            .lineSpacing(title * (h2LineHeight - 1))
    }
    
    static func subheadline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: subheadline, weight: .medium, design: .rounded))
            .lineSpacing(subheadline * (bodyLineHeight - 1))
    }
}

// MARK: - Spacing System (Liquid Glass - Premium Spacing Inspired by Calm/Headspace)
struct AppSpacing {
    // Base spacing (premium, generous spacing for clean design)
    static let xs: CGFloat = 8   // 0.5x - minimal spacing
    static let sm: CGFloat = 16  // 1x - standard spacing (increased for premium feel)
    static let md: CGFloat = 24  // 1.5x - comfortable spacing (increased)
    static let lg: CGFloat = 40  // 2.5x - generous spacing (increased)
    static let xl: CGFloat = 56  // 3.5x - extra generous (increased)
    static let xxl: CGFloat = 80 // 5x - maximum spacing (increased)
    
    // Component-specific spacing (premium, inspired by calm.com/headspace)
    static let orbMinDistance: CGFloat = 180 // Minimum between orbs (more breathing room)
    static let dockItemSpacing: CGFloat = 28  // Dock items (more space between)
    static let dockPadding: CGFloat = 40      // Dock padding (more generous)
    static let edgePadding: CGFloat = 40      // Edge padding (more generous for premium feel)
    
    // Liquid Glass specific (premium spacing)
    static let tapTarget: CGFloat = 48        // Minimum tap target (larger for comfort)
    static let elementSpacing: CGFloat = 28   // Between interactive elements (more space)
    static let sectionSpacing: CGFloat = 48   // Between major sections (more breathing room)
    static let cardPadding: CGFloat = 28       // Inside cards/panels (more generous)
    
    // Safe area specific
    static let safeAreaTopPadding: CGFloat = 8   // Additional padding above safe area
    static let safeAreaBottomPadding: CGFloat = 12 // Additional padding below safe area
}

struct AppTheme {
    // Brand colors (content-driven approach)
    static let accent = Color(red: 0.3, green: 0.6, blue: 0.9) // Soft blue
    static let accentDark = Color(red: 0.2, green: 0.4, blue: 0.7) // Deeper blue
    static let rainBlue = Color(red: 0.4, green: 0.7, blue: 1.0) // Bright rain blue
    static let glassGray = Color.white.opacity(0.1)
    static let glassBorder = Color.white.opacity(0.2)
    
    // Primary brand colors (moved to content layer)
    static let primary = SoundColor.rain
    static let secondary = SoundColor.ocean
    static let accentColor = SoundColor.fireplace
    
    // Liquid Glass color system (content-driven)
    // Colors blend into background, controls use translucent materials
    static let liquidGlassBackground: Color = Color.white.opacity(0.05)
    static let liquidGlassBorder: Color = Color.white.opacity(0.15)
    static let liquidGlassHighlight: Color = Color.white.opacity(0.1)
    
    // Content layer colors (for backgrounds that show through controls)
    static func contentGradient(for activeTracks: [String]) -> LinearGradient {
        // Blend active track colors into gradient
        let trackColors = Array(activeTracks.prefix(3).map { SoundColor.colorForTrack($0) })
        let defaultColors = [primary, secondary, accentColor]
        let combinedColors = trackColors.isEmpty ? defaultColors : (trackColors + defaultColors)
        let gradientColors = Array(combinedColors.prefix(3))
        
        return LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Background - enhanced deep space aesthetic
    static let background = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.08, blue: 0.12), // Deepest
            Color(red: 0.08, green: 0.12, blue: 0.18), // Mid
            Color(red: 0.12, green: 0.16, blue: 0.22), // Lighter
            Color(red: 0.08, green: 0.12, blue: 0.18), // Mid
            Color(red: 0.05, green: 0.08, blue: 0.12)  // Deepest
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Glass morphism background
    static let glassBackground = Material.ultraThinMaterial
    
    // Legacy card background (for unused views - using glass style)
    static let cardBackground = Color.white.opacity(0.1)
    
    // Glass card style (legacy - use GlassCard modifier instead)
    static func glassCard() -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(glassBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    static let gradient = LinearGradient(
        colors: [accent, rainBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Animation constants
    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        
        // Liquid Glass specific animations
        static let liquidSpring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.75)
        static let fluid = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let micro = SwiftUI.Animation.easeOut(duration: 0.2)
    }
    
    // Blur intensity scale (for reference)
    struct BlurScale {
        static let ultraLight: CGFloat = 5   // Subtle
        static let light: CGFloat = 10        // Standard
        static let medium: CGFloat = 20       // Emphasis
        static let heavy: CGFloat = 30        // Strong emphasis
    }
    
    // Opacity scale (for reference)
    struct OpacityScale {
        static let background: (min: Double, max: Double) = (0.3, 0.5)  // Background layer
        static let content: (min: Double, max: Double) = (0.6, 0.8)      // Content layer
        static let controls: (min: Double, max: Double) = (0.8, 0.95)    // Control layer
        static let text: (min: Double, max: Double) = (1.0, 1.0)         // Text layer
    }
}
