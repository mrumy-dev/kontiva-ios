import SwiftUI
import KontivaCore

/// First-run setup (skeleton): welcome + create the encrypted vault. The full
/// 3-step flow (profile, themes, etc.) gets ported in a later phase.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var passphrase = ""
    @State private var confirm = ""
    @State private var acknowledged = false

    private var canContinue: Bool {
        acknowledged && !passphrase.isEmpty && passphrase == confirm
    }

    var body: some View {
        VStack(spacing: KontivaTheme.Space.md) {
            Spacer()
            Image("BrandIcon")
                .resizable().scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                .shadow(color: KontivaTheme.charcoal.opacity(0.18), radius: 14, y: 7)
            Image("Wordmark")
                .resizable().scaledToFit()
                .frame(height: 30)
                .padding(.top, KontivaTheme.Space.xs)
            Text("Ruhige, private Übersicht über Ihr Schweizer Budget – komplett auf diesem Gerät.")
                .font(.callout).foregroundStyle(KontivaTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: KontivaTheme.Space.sm) {
                SecureField("Passphrase", text: $passphrase).textFieldStyle(.roundedBorder)
                SecureField("Passphrase bestätigen", text: $confirm).textFieldStyle(.roundedBorder)
                if !confirm.isEmpty && confirm != passphrase {
                    Text("Passphrasen stimmen nicht überein.")
                        .font(.caption).foregroundStyle(KontivaTheme.swissRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle(isOn: $acknowledged) {
                    Text("Ich verstehe, dass es keine Wiederherstellung gibt. Ich notiere die Passphrase sicher.")
                        .font(.caption).foregroundStyle(KontivaTheme.textSecondary)
                }
            }
            .padding(.top, KontivaTheme.Space.sm)

            Button {
                Task { await model.setUp(passphrase: passphrase) }
            } label: {
                HStack {
                    if model.isWorking { ProgressView().tint(.white) }
                    Text("Los geht's").fontWeight(.semibold)
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(KontivaTheme.accent)
            .controlSize(.large)
            .disabled(!canContinue || model.isWorking)

            Spacer()
        }
        .padding(KontivaTheme.Space.xl)
    }
}
