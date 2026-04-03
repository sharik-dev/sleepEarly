// sleepEarly/Theme.swift
import SwiftUI

enum Theme {

    // MARK: - Background Layers
    static let backgroundPrimary   = Color(hex: "0A0F1E")
    static let backgroundSecondary = Color(hex: "111827")
    static let backgroundCard      = Color(hex: "1A2540")
    static let backgroundElevated  = Color(hex: "1E2D4A")

    // MARK: - Accent Colors
    static let accentPrimary   = Color(hex: "4F6EF7")
    static let accentSecondary = Color(hex: "5ECFCD")
    static let accentGold      = Color(hex: "FFB800")
    static let accentDanger    = Color(hex: "FF6B6B")
    static let accentWarning   = Color(hex: "FFAA4C")
    static let accentSuccess   = Color(hex: "4ECBA0")

    // MARK: - Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: "8B9DC3")
    static let textTertiary  = Color(hex: "4A5780")

    // MARK: - Borders
    static let borderGlass       = Color.white.opacity(0.13)
    static let borderGlassActive = Color.white.opacity(0.30)
    static let separator         = Color.white.opacity(0.08)

    // MARK: - Gradients
    static let gradientBackground = LinearGradient(
        colors: [Color(hex: "0A0F1E"), Color(hex: "0D1528"), Color(hex: "0A0F1E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientAccent = LinearGradient(
        colors: [accentPrimary, accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientAccentDiag = LinearGradient(
        colors: [accentPrimary, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientGold = LinearGradient(
        colors: [accentGold, Color(hex: "FF8C00")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Shape Constants
    static let cornerRadiusCard:   CGFloat = 20
    static let cornerRadiusButton: CGFloat = 14
    static let cornerRadiusSmall:  CGFloat = 10

    // Tab bar height — used for bottom padding
    static let tabBarHeight: CGFloat = 90
}

// MARK: - Hex Color Init
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - GlassCard Modifier
struct GlassCard: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = Theme.cornerRadiusCard

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Theme.borderGlass, lineWidth: 1)
                    )
                    .shadow(color: Color.white.opacity(0.03), radius: 1, x: 0, y: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 8)
    }
}

// MARK: - GlowText Modifier
struct GlowText: ViewModifier {
    var color: Color
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.4), radius: radius)
            .shadow(color: color.opacity(0.2), radius: radius * 2)
    }
}

// MARK: - PrimaryButtonStyle
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(Theme.gradientAccent)
                    .shadow(color: Theme.accentPrimary.opacity(0.5), radius: 16, x: 0, y: 6)
            )
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - GhostButtonStyle
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .strokeBorder(Theme.borderGlass, lineWidth: 1.5)
                    .background(Capsule().fill(Theme.backgroundCard))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions
extension View {
    func glassCard(padding: CGFloat = 20, cornerRadius: CGFloat = Theme.cornerRadiusCard) -> some View {
        modifier(GlassCard(padding: padding, cornerRadius: cornerRadius))
    }

    func glowText(color: Color, radius: CGFloat = 12) -> some View {
        modifier(GlowText(color: color, radius: radius))
    }
}
