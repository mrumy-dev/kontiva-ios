import SwiftUI
import KontivaCore

/// First-run flow: a warm welcome hero, then create a numeric unlock code.
/// (The code is the vault secret — AES-256-GCM / PBKDF2 under the hood. Face ID can
/// be turned on afterwards in Einstellungen.)
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    private enum Step { case welcome, choose, confirm }
    @State private var step: Step = .welcome
    @State private var pin = ""
    @State private var firstPin = ""
    @State private var attempts = 0
    @State private var mismatch = false

    private let length = 6

    var body: some View {
        ZStack {
            KontivaTheme.pageGradient.ignoresSafeArea()
            Group {
                switch step {
                case .welcome: welcomeHero
                case .choose:  pinStep(title: "Code festlegen", subtitle: noRecoveryNote, error: false)
                case .confirm: pinStep(title: "Code bestätigen", subtitle: nil, error: mismatch)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .animation(.snappy(duration: 0.35), value: step)
    }

    // MARK: Step 1 — welcome

    private var welcomeHero: some View {
        VStack(spacing: 0) {
            Spacer(minLength: KontivaTheme.Space.lg)

            ZStack {
                Circle().fill(KontivaTheme.accent.opacity(0.12)).frame(width: 132, height: 132)
                Image("BrandIcon")
                    .resizable().scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .shadow(color: KontivaTheme.charcoal.opacity(0.18), radius: 14, y: 7)
            }

            Text(loc(.lockWelcomeSetup))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(KontivaTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, KontivaTheme.Space.md)

            Text(loc(.onboardingIntroBody))
                .font(.callout).foregroundStyle(KontivaTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, KontivaTheme.Space.xs)
                .padding(.horizontal, KontivaTheme.Space.sm)

            VStack(spacing: 0) {
                cue("lock.shield.fill", loc(.onboardingFeaturePrivate))
                Divider().background(KontivaTheme.softBorder.opacity(0.4)).padding(.leading, 58)
                cue("mountain.2.fill", loc(.onboardingFeatureSecure))
                Divider().background(KontivaTheme.softBorder.opacity(0.4)).padding(.leading, 58)
                cue("chart.pie.fill", loc(.onboardingFeatureMoney))
            }
            .background(RoundedRectangle(cornerRadius: KontivaTheme.Radius.card, style: .continuous)
                .fill(KontivaTheme.cardSurface))
            .overlay(RoundedRectangle(cornerRadius: KontivaTheme.Radius.card, style: .continuous)
                .strokeBorder(KontivaTheme.softBorder.opacity(0.5), lineWidth: 1))
            .shadow(color: KontivaTheme.charcoal.opacity(0.05), radius: 12, y: 4)
            .padding(.top, KontivaTheme.Space.xl)

            Spacer(minLength: KontivaTheme.Space.lg)

            Button { advance(to: .choose) } label: {
                Text(loc(.onboardingStart)).fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(KontivaTheme.accent).controlSize(.large)

            securityFooter.padding(.top, KontivaTheme.Space.md)
        }
        .padding(.horizontal, KontivaTheme.Space.xl)
        .padding(.vertical, KontivaTheme.Space.lg)
    }

    private func cue(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: KontivaTheme.Space.sm) {
            KontivaIconTile(symbol, size: 34)
            Text(text).font(.subheadline).foregroundStyle(KontivaTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(KontivaTheme.Space.md)
    }

    // MARK: Steps 2 & 3 — choose / confirm code

    private var noRecoveryNote: String? { "Mind. 6 Ziffern · keine Wiederherstellung" }

    private func pinStep(title: String, subtitle: String?, error: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: KontivaTheme.Space.lg)
            Image("Wordmark").resizable().scaledToFit().frame(maxWidth: 180).frame(height: 40)

            Text(title)
                .font(.title3.weight(.medium)).foregroundStyle(KontivaTheme.textPrimary)
                .padding(.top, KontivaTheme.Space.md)

            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                    .padding(.top, KontivaTheme.Space.xxs)
            }

            PinDots(count: length, filled: pin.count, error: error)
                .modifier(Shake(animatableData: CGFloat(attempts)))
                .padding(.top, KontivaTheme.Space.xl)

            Text("Codes stimmen nicht überein")
                .font(.caption).foregroundStyle(KontivaTheme.swissRed)
                .opacity(error ? 1 : 0)
                .padding(.top, KontivaTheme.Space.sm)

            Spacer(minLength: KontivaTheme.Space.lg)

            PinKeypad(onDigit: append, onDelete: deleteLast).disabled(model.isWorking)

            Spacer(minLength: KontivaTheme.Space.md)
            securityFooter.padding(.bottom, KontivaTheme.Space.md)
        }
        .padding(.horizontal, KontivaTheme.Space.lg)
    }

    // MARK: Entry logic

    private func append(_ digit: Int) {
        guard pin.count < length, !model.isWorking else { return }
        mismatch = false
        pin.append(String(digit))
        if pin.count == length { complete() }
    }

    private func deleteLast() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
        mismatch = false
    }

    private func complete() {
        switch step {
        case .welcome:
            break
        case .choose:
            firstPin = pin
            pin = ""
            advance(to: .confirm)
        case .confirm:
            if pin == firstPin {
                Haptics.success()
                let code = pin
                Task { await model.setUp(passphrase: code) }   // creates the vault → unlocks
            } else {
                Haptics.error()
                mismatch = true
                withAnimation(.linear(duration: 0.4)) { attempts += 1 }
                Task {
                    try? await Task.sleep(for: .milliseconds(550))
                    pin = ""; firstPin = ""
                    advance(to: .choose)
                }
            }
        }
    }

    private func advance(to next: Step) {
        withAnimation(.snappy(duration: 0.35)) { step = next }
    }

    private var securityFooter: some View {
        HStack(spacing: 5) { Image(systemName: "lock.fill"); Text("AES-256-GCM · kein Server · keine Cloud") }
            .font(.caption2).foregroundStyle(KontivaTheme.textTertiary)
    }
}
