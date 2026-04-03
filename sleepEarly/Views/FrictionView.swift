// sleepEarly/Views/FrictionView.swift
import SwiftUI

struct FrictionView: View {
    @Binding var isPresented: Bool
    @State private var tapCount = 0
    @State private var moonScale: CGFloat = 1.0
    @State private var showContent = false

    private let messages = [
        "Tu es sûr ?",
        "Vraiment sûr ?",
        "OK, mais tu le regretteras demain. 😴"
    ]

    private var buttonLabel: String {
        tapCount == 0 ? "J'ignore" : messages[min(tapCount - 1, messages.count - 1)]
    }

    private var canDismiss: Bool { tapCount >= 3 }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            // Aurora glow
            RadialGradient(
                colors: [Theme.accentPrimary.opacity(0.13), Color.clear],
                center: .top,
                startRadius: 60,
                endRadius: 440
            )
            .ignoresSafeArea()

            // Starfield
            StarfieldView()
                .ignoresSafeArea()
                .opacity(0.32)

            VStack(spacing: 44) {
                // Moon with concentric glow rings
                ZStack {
                    Circle()
                        .fill(Theme.accentGold.opacity(0.05))
                        .frame(width: 190, height: 190)
                    Circle()
                        .fill(Theme.accentGold.opacity(0.09))
                        .frame(width: 145, height: 145)

                    Image(systemName: "moon.stars.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78)
                        .foregroundStyle(Theme.accentGold)
                        .glowText(color: Theme.accentGold, radius: 20)
                        .symbolEffect(.pulse.byLayer, options: .repeating)
                        .scaleEffect(moonScale)
                }

                // Text
                VStack(spacing: 10) {
                    Text("Tu aurais dû dormir")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Il est \(currentTimeString())")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                // Progress pips
                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i < tapCount ? Theme.accentPrimary : Theme.textTertiary.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .shadow(
                                color: i < tapCount ? Theme.accentPrimary.opacity(0.85) : .clear,
                                radius: 6
                            )
                            .animation(.spring(response: 0.3), value: tapCount)
                    }
                }

                // Dismiss button
                Button {
                    if canDismiss {
                        withAnimation(.easeOut(duration: 0.3)) { isPresented = false }
                    } else {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
                            moonScale = 1.18
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                moonScale = 1.0
                            }
                        }
                        tapCount += 1
                    }
                } label: {
                    Text(buttonLabel)
                        .frame(minWidth: 180)
                }
                .buttonStyle(canDismiss ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(GhostButtonStyle()))
                .animation(.easeInOut(duration: 0.25), value: canDismiss)
            }
            .padding(36)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                showContent = true
            }
        }
    }

    private func currentTimeString() -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: Date())
    }
}

// MARK: - AnyButtonStyle (type-erased wrapper to allow conditional ButtonStyle)
private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (ButtonStyle.Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}
