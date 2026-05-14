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
    @ViewBuilder
    func liquidGlass(intensity: Double = 1.0, cornerRadius: CGFloat = 20, blurIntensity: LiquidGlass.BlurIntensity = .light, opacityLevel: LiquidGlass.OpacityLevel = .content) -> some View {
        // Check if liquid glass effects are enabled
        let effectsEnabled = SettingsManager.shared.liquidGlassEffects
        if effectsEnabled {
            modifier(LiquidGlass(intensity: intensity, cornerRadius: cornerRadius, blurIntensity: blurIntensity, opacityLevel: opacityLevel))
        } else {
            // Return view with simple background instead of liquid glass
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Phase 1: Enhanced Liquid Glass for Controls & Navigation
enum LiquidGlassVariant {
    case regular  // For most controls and navigation (blurs background, maintains legibility)
    case clear    // For components over visually rich backgrounds (highly translucent)
}

// MARK: - Liquid Glass Control Modifier (for controls and navigation)
struct LiquidGlassControl: ViewModifier {
    var variant: LiquidGlassVariant = .regular
    var cornerRadius: CGFloat = 0 // 0 = no corner radius (for full-width elements)
    var opacity: Double = 0.90 // Higher opacity for controls (0.85-0.95 range)
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base material - use regular material for controls
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(variant == .clear ? 0.6 : opacity)
                    
                    // For clear variant, add dimming layer if needed
                    if variant == .clear {
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .blendMode(.multiply)
                    }
                }
            }
            .clipShape(cornerRadius > 0 ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)) : AnyShape(Rectangle()))
    }
}

// Helper to fix type mismatch in ternary expressions
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Liquid Glass Content Modifier (for content layer - uses standard materials)
struct LiquidGlassContent: ViewModifier {
    var material: Material = .ultraThin
    var cornerRadius: CGFloat = 20
    var opacity: Double = 1.0
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
                    .opacity(opacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - View Extensions for Phase 1
extension View {
    /// Liquid Glass for controls and navigation (functional layer)
    /// Use this for: tab bars, navigation bars, toolbars, buttons, popovers
    @ViewBuilder
    func liquidGlassControl(variant: LiquidGlassVariant = .regular, cornerRadius: CGFloat = 0, opacity: Double = 0.90) -> some View {
        let effectsEnabled = SettingsManager.shared.liquidGlassEffects
        if effectsEnabled {
            modifier(LiquidGlassControl(variant: variant, cornerRadius: cornerRadius, opacity: opacity))
        } else {
            // Fallback to simple background
            self.background(
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .clipShape(cornerRadius > 0 ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius)) : AnyShape(Rectangle()))
            )
        }
    }
    
    /// Standard materials for content layer
    /// Use this for: cards, panels, list items, content backgrounds
    func liquidGlassContent(material: Material = .ultraThin, cornerRadius: CGFloat = 20, opacity: Double = 1.0) -> some View {
        modifier(LiquidGlassContent(material: material, cornerRadius: cornerRadius, opacity: opacity))
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

// MARK: - Phase 7: Design Tokens - Spacing System
/// Comprehensive spacing system following 8pt grid
struct AppSpacing {
    // Base spacing (8pt grid system)
    static let xs: CGFloat = 8   // 1x - minimal spacing
    static let sm: CGFloat = 16  // 2x - standard spacing
    static let md: CGFloat = 24  // 3x - comfortable spacing
    static let lg: CGFloat = 40  // 5x - generous spacing
    static let xl: CGFloat = 56  // 7x - extra generous
    static let xxl: CGFloat = 80 // 10x - maximum spacing
    
    // Icon spacing (Phase 3: Circular Design)
    static let iconSpacing: CGFloat = 16      // Between icons
    static let iconContainer: CGFloat = 56     // Base icon size (primary)
    static let iconContainerSecondary: CGFloat = 48  // Secondary icon size
    static let iconContainerTertiary: CGFloat = 40    // Tertiary icon size
    
    // Material spacing (Phase 6: Content Materials)
    static let materialPadding: CGFloat = 20  // Inside materials
    static let materialGap: CGFloat = 12      // Between material elements
    
    // Component-specific spacing
    static let orbMinDistance: CGFloat = 180  // Minimum between orbs
    static let dockItemSpacing: CGFloat = 28   // Dock items
    static let dockPadding: CGFloat = 40       // Dock padding
    static let edgePadding: CGFloat = 40       // Edge padding
    
    // Interactive elements (Phase 5: Motion)
    static let tapTarget: CGFloat = 48        // Minimum tap target (Apple HIG)
    static let elementSpacing: CGFloat = 28    // Between interactive elements
    static let sectionSpacing: CGFloat = 48    // Between major sections
    static let cardPadding: CGFloat = 28       // Inside cards/panels
    
    // Safe area specific
    static let safeAreaTopPadding: CGFloat = 8    // Additional padding above safe area
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
        // Instant animation (effectively no animation)
        private static let noAnimation = SwiftUI.Animation.linear(duration: 0)
        
        static func spring(reduceMotion: Bool = false) -> SwiftUI.Animation {
            reduceMotion ? noAnimation : .spring(response: 0.4, dampingFraction: 0.8)
        }
        
        static func smooth(reduceMotion: Bool = false) -> SwiftUI.Animation {
            reduceMotion ? noAnimation : .easeInOut(duration: 0.3)
        }
        
        static func quick(reduceMotion: Bool = false) -> SwiftUI.Animation {
            reduceMotion ? noAnimation : .easeInOut(duration: 0.2)
        }
        
        // Liquid Glass specific animations
        static func liquidSpring(reduceMotion: Bool = false) -> SwiftUI.Animation {
            reduceMotion ? noAnimation : .spring(response: 0.5, dampingFraction: 0.75)
        }
        
        static func fluid(reduceMotion: Bool = false) -> SwiftUI.Animation {
            reduceMotion ? noAnimation : .easeInOut(duration: 0.4)
        }
        
        static func micro(reduceMotion: Bool = false) -> SwiftUI.Animation {
            reduceMotion ? noAnimation : .easeOut(duration: 0.2)
        }
        
        // Legacy static properties for backward compatibility (will respect reduce motion via helper)
        static var spring: SwiftUI.Animation {
            shouldReduceMotion() ? noAnimation : .spring(response: 0.4, dampingFraction: 0.8)
        }
        
        static var smooth: SwiftUI.Animation {
            shouldReduceMotion() ? noAnimation : .easeInOut(duration: 0.3)
        }
        
        static var quick: SwiftUI.Animation {
            shouldReduceMotion() ? noAnimation : .easeInOut(duration: 0.2)
        }
        
        static var liquidSpring: SwiftUI.Animation {
            shouldReduceMotion() ? noAnimation : .spring(response: 0.5, dampingFraction: 0.75)
        }
        
        static var fluid: SwiftUI.Animation {
            shouldReduceMotion() ? noAnimation : .easeInOut(duration: 0.4)
        }
        
        static var micro: SwiftUI.Animation {
            shouldReduceMotion() ? noAnimation : .easeOut(duration: 0.2)
        }
        
        // Helper to check if motion should be reduced
        static func shouldReduceMotion() -> Bool {
            #if canImport(UIKit)
            return UIAccessibility.isReduceMotionEnabled || SettingsManager.shared.reduceMotion
            #else
            return SettingsManager.shared.reduceMotion
            #endif
        }
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

// MARK: - Phase 8: Design Tokens

/// Material opacity scale for consistent material usage
struct MaterialOpacity {
    // Liquid Glass (controls/navigation)
    struct LiquidGlass {
        static let control: (min: Double, max: Double) = (0.85, 0.95)      // Control elements
        static let navigation: (min: Double, max: Double) = (0.90, 0.95) // Navigation bars
        static let button: (min: Double, max: Double) = (0.85, 0.95)      // Buttons
    }
    
    // Standard Materials (content)
    struct Standard {
        static let ultraThin: (min: Double, max: Double) = (0.25, 0.45)  // Subtle separation
        static let thin: (min: Double, max: Double) = (0.45, 0.65)       // More definition
        static let regular: (min: Double, max: Double) = (0.65, 0.85)    // Strong separation
        static let thick: (min: Double, max: Double) = (0.85, 0.95)      // Dark overlays
    }
    
    // Helper to get opacity value
    static func liquidGlass(_ type: LiquidGlassType = .control) -> Double {
        switch type {
        case .control:
            return LiquidGlass.control.max
        case .navigation:
            return LiquidGlass.navigation.max
        case .button:
            return LiquidGlass.button.max
        }
    }
    
    static func standard(_ type: StandardType = .thin) -> Double {
        switch type {
        case .ultraThin:
            return Standard.ultraThin.max
        case .thin:
            return Standard.thin.max
        case .regular:
            return Standard.regular.max
        case .thick:
            return Standard.thick.max
        }
    }
    
    enum LiquidGlassType {
        case control
        case navigation
        case button
    }
    
    enum StandardType {
        case ultraThin
        case thin
        case regular
        case thick
    }
}

/// Animation timing constants for consistent animations
struct AnimationTiming {
    // Ambient animations (slow, continuous)
    struct Ambient {
        static let particleDrift: TimeInterval = 120  // 2 minutes per cycle
        static let waveCycle: TimeInterval = 10      // 10 seconds per cycle
        static let fogPulse: TimeInterval = 45       // 45 seconds per cycle
        static let depthBreathing: TimeInterval = 60 // 60 seconds per cycle
    }
    
    // Interactive animations (quick, responsive)
    struct Interactive {
        static let buttonPress: TimeInterval = 0.2   // Button press feedback
        static let tap: TimeInterval = 0.15           // Tap feedback
        static let transition: TimeInterval = 0.4     // View transitions
        static let smooth: TimeInterval = 0.3         // Smooth transitions
        static let quick: TimeInterval = 0.2          // Quick transitions
        static let micro: TimeInterval = 0.15         // Micro-interactions
    }
    
    // Spring physics
    struct Spring {
        static let interactive: (response: Double, damping: Double) = (0.3, 0.7)  // Interactive feedback
        static let transition: (response: Double, damping: Double) = (0.4, 0.8)   // Transitions
        static let liquid: (response: Double, damping: Double) = (0.5, 0.75)       // Liquid Glass
    }
    
    // Helper to create spring animation
    static func spring(_ type: SpringType = .interactive) -> SwiftUI.Animation {
        let config: (response: Double, damping: Double)
        switch type {
        case .interactive:
            config = Spring.interactive
        case .transition:
            config = Spring.transition
        case .liquid:
            config = Spring.liquid
        }
        
        if MotionSystem.shouldReduceMotion {
            return .linear(duration: 0)
        }
        
        return .spring(response: config.response, dampingFraction: config.damping)
    }
    
    enum SpringType {
        case interactive
        case transition
        case liquid
    }
}

// MARK: - Phase 4: Color & Contrast System
/// Vibrant color system for proper contrast on materials
struct AppColors {
    // Text colors on materials (vibrant for proper contrast)
    static let primaryText = Color.white // For dark mode backgrounds
    static let secondaryText = Color.white.opacity(0.8) // For secondary content
    static let tertiaryText = Color.white.opacity(0.6) // For tertiary content
    static let quaternaryText = Color.white.opacity(0.4) // For quaternary content
    
    // System colors (adapt to light/dark mode)
    static let label = Color.primary // Adapts to light/dark
    static let secondaryLabel = Color.secondary // Adapts to light/dark
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel) // System tertiary
    static let quaternaryLabel = Color(uiColor: .quaternaryLabel) // System quaternary
    
    // Icon colors
    static let iconActive = Color.white // For active icons
    static let iconInactive = Color.white.opacity(0.9) // For inactive icons
    static let iconDisabled = Color.white.opacity(0.4) // For disabled icons
    
    // Helper function to get vibrant text color for dark backgrounds
    static func textOnMaterial(level: TextLevel = .primary) -> Color {
        switch level {
        case .primary:
            return primaryText
        case .secondary:
            return secondaryText
        case .tertiary:
            return tertiaryText
        case .quaternary:
            return quaternaryText
        }
    }
    
    enum TextLevel {
        case primary
        case secondary
        case tertiary
        case quaternary
    }
}

// MARK: - Color Extension for Dynamic Adaptation
extension Color {
    /// Returns a color that adapts to light/dark mode
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light:
                return UIColor(light)
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(dark)
            }
        })
        #else
        return dark
        #endif
    }
    
    /// Returns a color that works in increased contrast mode
    static func highContrast(_ baseColor: Color, increased: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { traitCollection in
            if traitCollection.accessibilityContrast == .high {
                return UIColor(increased)
            }
            return UIColor(baseColor)
        })
        #else
        return baseColor
        #endif
    }
}

// MARK: - Phase 6: Content Layer Materials
/// Standard materials for content (not Liquid Glass)
struct ContentMaterial {
    /// Material types for content
    enum MaterialType {
        case ultraThin  // Subtle separation
        case thin       // More definition
        case regular    // Strong separation
        case thick      // Dark overlays
        
        var material: Material {
            switch self {
            case .ultraThin: return .ultraThinMaterial
            case .thin: return .thinMaterial
            case .regular: return .regularMaterial
            case .thick: return .thickMaterial
            }
        }
    }
    
    /// Content card modifier
    struct ContentCard: ViewModifier {
        let materialType: MaterialType
        let cornerRadius: CGFloat
        let padding: CGFloat
        
        init(materialType: MaterialType = .thin, cornerRadius: CGFloat = 20, padding: CGFloat = AppSpacing.md) {
            self.materialType = materialType
            self.cornerRadius = cornerRadius
            self.padding = padding
        }
        
        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(materialType.material)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    /// List item modifier
    struct ListItem: ViewModifier {
        let cornerRadius: CGFloat
        let padding: CGFloat
        
        init(cornerRadius: CGFloat = 12, padding: CGFloat = AppSpacing.sm) {
            self.cornerRadius = cornerRadius
            self.padding = padding
        }
        
        func body(content: Content) -> some View {
            content
                .padding(.vertical, padding)
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    /// Section background modifier
    struct SectionBackground: ViewModifier {
        let cornerRadius: CGFloat
        let padding: CGFloat
        
        init(cornerRadius: CGFloat = 20, padding: CGFloat = AppSpacing.md) {
            self.cornerRadius = cornerRadius
            self.padding = padding
        }
        
        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(Material.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Apply content card styling (standard material, not Liquid Glass)
    func contentCard(materialType: ContentMaterial.MaterialType = .thin, cornerRadius: CGFloat = 20, padding: CGFloat = AppSpacing.md) -> some View {
        modifier(ContentMaterial.ContentCard(materialType: materialType, cornerRadius: cornerRadius, padding: padding))
    }
    
    /// Apply list item styling (ultraThin material)
    func contentListItem(cornerRadius: CGFloat = 12, padding: CGFloat = AppSpacing.sm) -> some View {
        modifier(ContentMaterial.ListItem(cornerRadius: cornerRadius, padding: padding))
    }
    
    /// Apply section background (thin material)
    func contentSection(cornerRadius: CGFloat = 20, padding: CGFloat = AppSpacing.md) -> some View {
        modifier(ContentMaterial.SectionBackground(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Phase 10: Performance Optimization
/// Performance management and optimization utilities
struct PerformanceManager {
    /// Maximum particle count for optimal performance
    static let maxParticleCount: Int = 20
    
    /// Maximum particles per track
    static let maxParticlesPerTrack: Int = 5
    
    /// Optimal blur radius for performance
    static let optimalBlurRadius: CGFloat = 10
    
    /// Maximum blur radius before performance impact
    static let maxBlurRadius: CGFloat = 20
    
    /// Check if device is in low power mode
    static var isLowPowerMode: Bool {
        #if os(iOS)
        return ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        return false
        #endif
    }
    
    /// Should reduce animations for performance
    static var shouldReduceAnimations: Bool {
        return AccessibilityManager.shouldReduceMotion || isLowPowerMode
    }
    
    /// Get optimal particle count based on active tracks
    static func optimalParticleCount(activeTracks: Int) -> Int {
        let total = activeTracks * maxParticlesPerTrack
        return min(total, maxParticleCount)
    }
    
    /// Get optimal blur radius based on performance settings
    static func optimalBlurRadius(baseRadius: CGFloat) -> CGFloat {
        if shouldReduceAnimations {
            return min(baseRadius * 0.5, optimalBlurRadius)
        }
        return min(baseRadius, maxBlurRadius)
    }
}

// MARK: - Phase 9: Accessibility System
/// Centralized accessibility management
struct AccessibilityManager {
    /// Check if motion should be reduced
    static var shouldReduceMotion: Bool {
        #if os(iOS)
        return UIAccessibility.isReduceMotionEnabled || SettingsManager.shared.reduceMotion
        #else
        return SettingsManager.shared.reduceMotion
        #endif
    }
    
    /// Check if increased contrast is enabled
    static var isIncreasedContrast: Bool {
        #if os(iOS)
        return UIAccessibility.isDarkerSystemColorsEnabled || UIAccessibility.isReduceTransparencyEnabled
        #else
        return false
        #endif
    }
    
    /// Check if VoiceOver is running
    static var isVoiceOverRunning: Bool {
        #if os(iOS)
        return UIAccessibility.isVoiceOverRunning
        #else
        return false
        #endif
    }
    
    /// Get accessibility label for sound track
    static func soundTrackLabel(name: String, isActive: Bool, volume: Int) -> String {
        let status = isActive ? "active" : "inactive"
        return "\(name) sound, \(status), volume \(volume) percent"
    }
    
    /// Get accessibility hint for sound track
    static func soundTrackHint(isActive: Bool) -> String {
        return isActive 
            ? "Double tap to stop. Drag to adjust volume."
            : "Double tap to play. Drag to adjust volume."
    }
    
    /// Get accessibility label for icon button
    static func iconButtonLabel(icon: String, title: String) -> String {
        return "\(title), \(icon) icon"
    }
    
    /// Get accessibility hint for icon button
    static func iconButtonHint(action: String) -> String {
        return "Double tap to \(action)"
    }
}

// MARK: - Phase 5: Motion & Animation System
/// Centralized motion and animation management
struct MotionSystem {
    /// Check if motion should be reduced (accessibility setting)
    static var shouldReduceMotion: Bool {
        AccessibilityManager.shouldReduceMotion
    }
    
    /// Interactive feedback animation (for button presses, taps)
    static var interactiveFeedback: SwiftUI.Animation {
        shouldReduceMotion 
            ? .linear(duration: 0)
            : .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    /// Transition animation (for view transitions)
    static var transition: SwiftUI.Animation {
        shouldReduceMotion
            ? .linear(duration: 0)
            : .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    /// Smooth transition (for content changes)
    static var smoothTransition: SwiftUI.Animation {
        shouldReduceMotion
            ? .linear(duration: 0)
            : .easeInOut(duration: 0.3)
    }
    
    /// Quick transition (for micro-interactions)
    static var quickTransition: SwiftUI.Animation {
        shouldReduceMotion
            ? .linear(duration: 0)
            : .easeOut(duration: 0.2)
    }
}

/// Haptic feedback system
struct HapticFeedback {
    /// Light impact (for subtle feedback)
    static func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Medium impact (for standard interactions)
    static func medium() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Heavy impact (for important actions)
    static func heavy() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    /// Selection feedback (for picker changes)
    static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
    
    /// Success feedback (for completed actions)
    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
    
    /// Error feedback (for errors)
    static func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }
    
    /// Warning feedback (for warnings)
    static func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }
}

/// Interactive feedback modifier
struct InteractiveFeedbackModifier: ViewModifier {
    @State private var isPressed = false
    let onPress: (() -> Void)?
    let hapticStyle: HapticStyle
    
    enum HapticStyle {
        case none
        case light
        case medium
        case heavy
        case selection
    }
    
    init(hapticStyle: HapticStyle = .medium, onPress: (() -> Void)? = nil) {
        self.hapticStyle = hapticStyle
        self.onPress = onPress
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(MotionSystem.interactiveFeedback, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            triggerHaptic()
                            onPress?()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
    
    private func triggerHaptic() {
        switch hapticStyle {
        case .none:
            break
        case .light:
            HapticFeedback.light()
        case .medium:
            HapticFeedback.medium()
        case .heavy:
            HapticFeedback.heavy()
        case .selection:
            HapticFeedback.selection()
        }
    }
}

extension View {
    /// Add interactive feedback to any view
    func interactiveFeedback(hapticStyle: InteractiveFeedbackModifier.HapticStyle = .medium, onPress: (() -> Void)? = nil) -> some View {
        modifier(InteractiveFeedbackModifier(hapticStyle: hapticStyle, onPress: onPress))
    }
}

// MARK: - Phase 3: Circular Icon Component
/// Circular icon with consistent sizing hierarchy and active/inactive states
struct CircularIcon: View {
    let icon: String
    let color: Color
    let isActive: Bool
    let size: IconSize
    var accessibilityLabel: String?
    var accessibilityHint: String?
    
    enum IconSize {
        case primary    // 56pt container, 28pt symbol
        case secondary  // 48pt container, 24pt symbol
        case tertiary   // 40pt container, 20pt symbol
        
        var containerSize: CGFloat {
            switch self {
            case .primary: return 56
            case .secondary: return 48
            case .tertiary: return 40
            }
        }
        
        var symbolSize: CGFloat {
            switch self {
            case .primary: return 28
            case .secondary: return 24
            case .tertiary: return 20
            }
        }
    }
    
    init(icon: String, color: Color, isActive: Bool = false, size: IconSize = .primary, accessibilityLabel: String? = nil, accessibilityHint: String? = nil) {
        self.icon = icon
        self.color = color
        self.isActive = isActive
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
    
    var body: some View {
        ZStack {
            // Glow halo (active only)
            if isActive {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.3),
                                color.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.containerSize * 0.7
                        )
                    )
                    .blur(radius: 8)
                    .frame(width: size.containerSize * 1.4, height: size.containerSize * 1.4)
            }
            
            // Main container
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: isActive ? [
                                    color.opacity(0.9),
                                    color.opacity(0.6)
                                ] : [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isActive ? 2 : 1.5
                        )
                )
                .frame(width: size.containerSize, height: size.containerSize)
                .shadow(
                    color: isActive ? color.opacity(0.6) : Color.black.opacity(0.2),
                    radius: isActive ? 12 : 4,
                    y: isActive ? 4 : 2
                )
                .scaleEffect(isActive ? 1.05 : 1.0)
            
            // Icon symbol - Phase 4: Use vibrant colors
            // Phase 9: Color independence - icon shape provides information, not just color
            Image(systemName: icon)
                .font(.system(size: size.symbolSize, weight: .medium))
                .foregroundStyle(isActive ? color : AppColors.iconInactive) // Vibrant color for contrast
        }
        .animation(AppTheme.Animation.liquidSpring, value: isActive)
        // Phase 9: Accessibility support
        .accessibilityLabel(accessibilityLabel ?? "\(icon) icon")
        .accessibilityHint(accessibilityHint ?? (isActive ? "Active" : "Inactive"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Phase 1: Button Components with Liquid Glass

/// Primary action button with colored Liquid Glass background
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let color: Color
    let isLoading: Bool
    let isDisabled: Bool
    
    init(
        _ title: String,
        icon: String? = nil,
        color: Color = AppTheme.accent,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.prepare()
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                // Colored Liquid Glass background (Phase 1)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay {
                        // Color tint for primary action
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.4),
                                        color.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                color.opacity(0.6),
                                color.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

/// Secondary button with regular Liquid Glass (monochromatic)
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .medium))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                // Regular Liquid Glass (monochromatic)
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .disabled(isLoading || isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}
