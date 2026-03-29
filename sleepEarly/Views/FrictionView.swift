// sleepEarly/Views/FrictionView.swift
import SwiftUI

struct FrictionView: View {
    @Binding var isPresented: Bool
    @State private var tapCount = 0

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
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                // Animation lune
                Image(systemName: "moon.stars.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .foregroundStyle(.yellow)
                    .symbolEffect(.pulse)

                VStack(spacing: 12) {
                    Text("Tu aurais dû dormir")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Il est \(currentTimeString())")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }

                // Indicateur de taps
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i < tapCount ? Color.white : Color.gray.opacity(0.4))
                            .frame(width: 10, height: 10)
                    }
                }

                Button {
                    if canDismiss {
                        isPresented = false
                    } else {
                        tapCount += 1
                    }
                } label: {
                    Text(buttonLabel)
                        .font(.body.bold())
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(canDismiss ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .animation(.easeInOut, value: tapCount)
            }
            .padding(32)
        }
    }

    private func currentTimeString() -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
