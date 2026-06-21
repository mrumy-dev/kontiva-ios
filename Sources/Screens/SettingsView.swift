import SwiftUI
import KontivaCore

/// Einstellungen — a single grouped iOS settings screen (the desktop uses a tabbed
/// window). Pushed inside the "Mehr" tab's navigation stack. Themes, backup/restore
/// and the avatar picker are follow-ups (backup/restore needs the iOS file pickers).
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    @State private var profileName = ""
    @State private var canton: Canton?
    @State private var showDeleteConfirm = false
    @State private var showChangePassphrase = false

    var body: some View {
        Form {
            profileSection
            languageSection
            securitySection
            dangerSection
            aboutSection
        }
        .tint(KontivaTheme.accent)
        .navigationTitle(loc(.navSettings))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadProfile)
        .sheet(isPresented: $showChangePassphrase) {
            ChangePassphraseSheet().environmentObject(model).environmentObject(loc)
        }
        .confirmationDialog(loc(.settingsDeleteAll), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(loc(.settingsDeleteAll), role: .destructive) { Task { await model.deleteAllLocalData() } }
            Button(loc(.commonCancel), role: .cancel) { }
        } message: {
            Text(loc(.lockRecoveryWarning))
        }
    }

    private var profileSection: some View {
        Section(loc(.settingsProfile)) {
            TextField(loc(.profileName), text: $profileName)
            Picker(loc(.settingsCanton), selection: $canton) {
                Text("—").tag(Canton?.none)
                ForEach(Canton.all) { c in
                    Text("\(c.name) (\(c.abbreviation))").tag(Canton?.some(c))
                }
            }
            Button(loc(.commonSave), action: saveProfile)
                .disabled(profileName.isEmpty)
        }
    }

    private var languageSection: some View {
        Section(loc(.settingsLanguage)) {
            Picker(loc(.settingsLanguage), selection: Binding(
                get: { model.settings.language },
                set: { model.setLanguage($0) })) {
                ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
            }
        }
    }

    private var securitySection: some View {
        Section {
            if model.biometricKind.isAvailable {
                Toggle(isOn: Binding(
                    get: { model.biometricEnabled },
                    set: { on in if on { _ = model.enableBiometric() } else { model.disableBiometric() } })) {
                    Label(model.biometricKind.label, systemImage: model.biometricKind.icon)
                }
            }
            Picker(loc(.settingsAutoLock), selection: Binding(
                get: { model.autoLock },
                set: { v in Task { await model.setAutoLock(v) } })) {
                ForEach(AutoLockInterval.allCases, id: \.self) { Text($0.displayLabel).tag($0) }
            }
            Button(loc(.settingsChangePassphrase)) { showChangePassphrase = true }
        } header: {
            Text(loc(.settingsSecurity))
        } footer: {
            Label(loc(.securityNote), systemImage: "lock.fill")
                .font(.caption).foregroundStyle(KontivaTheme.positive)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) { showDeleteConfirm = true } label: {
                Label(loc(.settingsDeleteAll), systemImage: "trash")
            }
        } header: {
            Text(loc(.settingsDangerZone))
        } footer: {
            Text(loc(.lockRecoveryWarning))
        }
    }

    private var aboutSection: some View {
        Section {
            Text(loc(.appTagline)).foregroundStyle(KontivaTheme.textSecondary)
            Label("local-first · offline-first · no telemetry · no network", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(KontivaTheme.positive)
            Label("AES-256-GCM · PBKDF2", systemImage: "key.fill")
                .font(.caption).foregroundStyle(KontivaTheme.textTertiary)
        } footer: {
            Text("Kontiva \(AppInfo.version)")
        }
    }

    private func loadProfile() {
        guard let h = model.household else { return }
        profileName = h.name
        canton = h.canton
    }

    private func saveProfile() {
        Task { await model.updateProfile(name: profileName, avatarName: model.household?.avatarName, canton: canton) }
    }
}

/// Change the passphrase. The store re-wraps the same master key, so existing data
/// stays readable; biometrics are kept in sync by the model.
private struct ChangePassphraseSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    @State private var oldPass = ""
    @State private var newPass = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(loc(.lockEnterPassphrase), text: $oldPass)
                    SecureField(loc(.settingsChangePassphrase), text: $newPass)
                }
                if failed {
                    Text(loc(.lockWrongPassphrase)).font(.caption).foregroundStyle(KontivaTheme.swissRed)
                }
            }
            .navigationTitle(loc(.settingsChangePassphrase))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc(.commonCancel)) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc(.commonSave), action: submit)
                        .fontWeight(.semibold)
                        .disabled(oldPass.isEmpty || newPass.isEmpty || model.isWorking)
                }
            }
        }
    }

    private func submit() {
        Task {
            let ok = await model.changePassphrase(old: oldPass, new: newPass)
            if ok { dismiss() } else { failed = true }
        }
    }
}
