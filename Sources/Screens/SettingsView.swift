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
    @State private var avatarName: String?
    @State private var showAvatarPicker = false
    @State private var showDeleteConfirm = false
    @State private var showChangePassphrase = false
    @State private var showBackup = false
    @State private var showRestore = false

    var body: some View {
        Form {
            profileSection
            languageSection
            themeSection
            securitySection
            dataSection
            dangerSection
            aboutSection
        }
        .tint(KontivaTheme.accent)
        .navigationTitle(loc(.navSettings))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadProfile)
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet(selected: $avatarName).environmentObject(loc)
        }
        .onChange(of: avatarName) { saveProfile() }
        .sheet(isPresented: $showChangePassphrase) {
            ChangePassphraseSheet().environmentObject(model).environmentObject(loc)
        }
        .sheet(isPresented: $showBackup) {
            BackupSheet().environmentObject(model).environmentObject(loc)
        }
        .sheet(isPresented: $showRestore) {
            RestoreSheet().environmentObject(model).environmentObject(loc)
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
            Button { showAvatarPicker = true } label: {
                HStack(spacing: KontivaTheme.Space.md) {
                    ProfileAvatar(name: avatarName, size: 52)
                    Text(profileName.isEmpty ? loc(.pdfDefaultHousehold) : profileName)
                        .font(.headline).foregroundStyle(KontivaTheme.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "pencil.circle").foregroundStyle(KontivaTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
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

    private var themeSection: some View {
        Section {
            HStack(spacing: KontivaTheme.Space.sm) {
                ForEach(AccentTheme.allCases) { accentSwatch($0) }
                Spacer(minLength: 0)
            }
            .padding(.vertical, KontivaTheme.Space.xxs)
        } header: {
            Text(loc(.settingsTheme))
        } footer: {
            Text(loc(model.settings.accent.labelKey))
        }
    }

    private func accentSwatch(_ theme: AccentTheme) -> some View {
        let selected = model.settings.accent == theme
        return Button { withAnimation(.snappy) { model.setAccent(theme) } } label: {
            ZStack {
                Circle().fill(theme.color).frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                }
            }
            .padding(3)
            .overlay(Circle().strokeBorder(selected ? theme.color : .clear, lineWidth: 2))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
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

    private var dataSection: some View {
        Section {
            Button { showBackup = true } label: { Label(loc(.settingsBackup), systemImage: "arrow.up.doc") }
            Button { showRestore = true } label: { Label(loc(.settingsRestore), systemImage: "arrow.down.doc") }
            Button(action: exportPDF) { Label(loc(.exportReport), systemImage: "doc.richtext") }
        } header: {
            Text(loc(.settingsData))
        } footer: {
            Text(loc(.backupSavedHint))
        }
    }

    private func exportPDF() {
        guard let data = ReportBuilder.makePDF(model: model) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(ReportBuilder.suggestedFilename(month: model.selectedMonth))
        try? data.write(to: url, options: [.atomic])
        Share.present([url])
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
        avatarName = h.avatarName
    }

    private func saveProfile() {
        Task { await model.updateProfile(name: profileName, avatarName: avatarName, canton: canton) }
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
