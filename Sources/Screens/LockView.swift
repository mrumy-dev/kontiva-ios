import SwiftUI

/// Unlock screen for an existing vault, with optional Face ID / Touch ID.
struct LockView: View {
    @EnvironmentObject private var model: AppModel
    @State private var passphrase = ""
    @State private var wrong = false
    @State private var triedBiometric = false

    private var canUseBiometrics: Bool { model.biometricEnabled && model.biometricKind.isAvailable }

    var body: some View {
        VStack(spacing: KontivaTheme.Space.lg) {
            Spacer()
            Image("BrandIcon")
                .resizable().scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: KontivaTheme.charcoal.opacity(0.18), radius: 12, y: 6)
            Text("Willkommen zurück").font(.title.bold())
            Text("Ihre Daten werden lokal und verschlüsselt gespeichert (AES-256-GCM).")
                .font(.caption).foregroundStyle(KontivaTheme.textTertiary)
                .multilineTextAlignment(.center)

            SecureField("Passphrase oder PIN", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit(submit)

            if wrong {
                Text("Falsche Passphrase").font(.caption).foregroundStyle(KontivaTheme.swissRed)
            }

            Button(action: submit) {
                HStack {
                    if model.isWorking { ProgressView().tint(.white) }
                    Text("Entsperren").fontWeight(.semibold)
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(KontivaTheme.accent)
            .controlSize(.large)
            .disabled(passphrase.isEmpty || model.isWorking)

            if canUseBiometrics {
                Button { unlockWithBiometrics() } label: {
                    Label("Mit \(model.biometricKind.label) entsperren", systemImage: model.biometricKind.icon)
                        .fontWeight(.medium)
                }
                .tint(KontivaTheme.accent)
                .controlSize(.large)
                .padding(.top, KontivaTheme.Space.xxs)
            }

            Spacer()
        }
        .padding(KontivaTheme.Space.xl)
        .task {
            // Offer Face ID automatically the first time the lock screen appears.
            if canUseBiometrics, !triedBiometric {
                triedBiometric = true
                unlockWithBiometrics()
            }
        }
    }

    private func submit() {
        guard !passphrase.isEmpty, !model.isWorking else { return }
        Task {
            let ok = await model.unlock(passphrase: passphrase)
            wrong = !ok
            if ok { passphrase = "" }
        }
    }

    private func unlockWithBiometrics() {
        Task { _ = await model.unlockWithBiometrics() }
    }
}
