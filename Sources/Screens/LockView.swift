import SwiftUI

/// Unlock screen for an existing vault. (Face ID / Touch ID will layer on later.)
struct LockView: View {
    @EnvironmentObject private var model: AppModel
    @State private var passphrase = ""
    @State private var wrong = false

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

            Spacer()
        }
        .padding(KontivaTheme.Space.xl)
    }

    private func submit() {
        guard !passphrase.isEmpty, !model.isWorking else { return }
        Task {
            let ok = await model.unlock(passphrase: passphrase)
            wrong = !ok
            if ok { passphrase = "" }
        }
    }
}
