import SwiftUI
import UIKit

/// A horizontal shake, used for wrong-PIN feedback (animate `animatableData`).
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    var travel: CGFloat = 9
    var shakes: CGFloat = 3
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// Light, native haptics for the keypad.
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

/// The filled/empty PIN indicator dots above the keypad.
struct PinDots: View {
    let count: Int
    let filled: Int
    var error: Bool = false

    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i < filled ? (error ? KontivaTheme.swissRed : KontivaTheme.accent) : .clear)
                    .frame(width: 13, height: 13)
                    .overlay(
                        Circle().strokeBorder(
                            error ? KontivaTheme.swissRed
                                  : (i < filled ? .clear : KontivaTheme.textTertiary.opacity(0.45)),
                            lineWidth: 1.5))
                    .animation(.snappy(duration: 0.18), value: filled)
            }
        }
    }
}

/// Press feedback for keypad keys: a subtle tint + scale.
struct PinKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(configuration.isPressed ? KontivaTheme.accent.opacity(0.14) : .clear))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A numeric keypad: 1–9, then [biometric] · 0 · [delete]. Biometric key only
/// appears when biometrics are enrolled + enabled.
struct PinKeypad: View {
    var biometric: BiometricKind? = nil
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    var onBiometric: (() -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 26), count: 3)
    private let keySize: CGFloat = 74

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...9, id: \.self) { digitKey($0) }
            biometricKey
            digitKey(0)
            deleteKey
        }
        .frame(maxWidth: 300)
    }

    private func digitKey(_ d: Int) -> some View {
        Button {
            Haptics.tap(); onDigit(d)
        } label: {
            Text("\(d)")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(KontivaTheme.textPrimary)
                .frame(width: keySize, height: keySize)
                .background(Circle().fill(KontivaTheme.cardSurface))
                .overlay(Circle().strokeBorder(KontivaTheme.softBorder.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PinKeyStyle())
    }

    @ViewBuilder private var biometricKey: some View {
        if let biometric, let onBiometric {
            Button { onBiometric() } label: {
                Image(systemName: biometric.icon)
                    .font(.system(size: 27))
                    .foregroundStyle(KontivaTheme.accent)
                    .frame(width: keySize, height: keySize)
            }
            .buttonStyle(PinKeyStyle())
        } else {
            Color.clear.frame(width: keySize, height: keySize)
        }
    }

    private var deleteKey: some View {
        Button { Haptics.tap(); onDelete() } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 24))
                .foregroundStyle(KontivaTheme.textSecondary)
                .frame(width: keySize, height: keySize)
        }
        .buttonStyle(PinKeyStyle())
    }
}
