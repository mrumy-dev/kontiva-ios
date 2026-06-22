import SwiftUI

/// The returning-user lock screen: a generous wordmark, a welcome line, PIN dots,
/// and a numeric keypad. If Face ID / Touch ID is enabled it auto-prompts on
/// appear and offers a key on the pad; the keypad is always the fallback.
struct LockView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    @State private var pin = ""
    @State private var wrong = false
    @State private var attempts = 0
    @State private var triedBiometric = false

    private let length = 6
    private var canUseBiometrics: Bool { model.biometricEnabled && model.biometricKind.isAvailable }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: KontivaTheme.Space.lg)

            Image("Wordmark")
                .resizable().scaledToFit()
                .frame(maxWidth: 210)
                .frame(height: 48)

            Text(loc(.lockWelcomeBack))
                .font(.title3.weight(.medium))
                .foregroundStyle(KontivaTheme.textSecondary)
                .padding(.top, KontivaTheme.Space.sm)

            PinDots(count: length, filled: pin.count, error: wrong)
                .modifier(Shake(animatableData: CGFloat(attempts)))
                .padding(.top, KontivaTheme.Space.xl)

            Text(loc(.lockWrongPassphrase))
                .font(.caption).foregroundStyle(KontivaTheme.swissRed)
                .opacity(wrong ? 1 : 0)
                .padding(.top, KontivaTheme.Space.sm)

            Spacer(minLength: KontivaTheme.Space.lg)

            PinKeypad(biometric: canUseBiometrics ? model.biometricKind : nil,
                      onDigit: append, onDelete: deleteLast, onBiometric: triggerBiometric)
                .disabled(model.isWorking)

            Spacer(minLength: KontivaTheme.Space.md)

            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                Text("AES-256-GCM")
            }
            .font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
            .padding(.bottom, KontivaTheme.Space.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, KontivaTheme.Space.lg)
        .background(KontivaTheme.pageGradient.ignoresSafeArea())
        .task {
            if canUseBiometrics, !triedBiometric {
                triedBiometric = true
                triggerBiometric()
            }
        }
    }

    private func append(_ digit: Int) {
        guard pin.count < length, !model.isWorking else { return }
        wrong = false
        pin.append(String(digit))
        if pin.count == length { submit() }
    }

    private func deleteLast() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
        wrong = false
    }

    private func submit() {
        let entered = pin
        Task {
            let ok = await model.unlock(passphrase: entered)
            if ok {
                Haptics.success()
                pin = ""
            } else {
                Haptics.error()
                wrong = true
                withAnimation(.linear(duration: 0.4)) { attempts += 1 }
                try? await Task.sleep(for: .milliseconds(500))
                pin = ""
            }
        }
    }

    private func triggerBiometric() {
        Task { _ = await model.unlockWithBiometrics() }
    }
}
