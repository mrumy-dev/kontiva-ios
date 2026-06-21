import SwiftUI
import UIKit
import UniformTypeIdentifiers
import KontivaCore
import KontivaPersistence

/// Presents a system share sheet (`UIActivityViewController`) so a file can be
/// saved to Files, AirDropped, etc. Presented directly on the top-most view
/// controller — wrapping `UIActivityViewController` in a SwiftUI `.sheet` renders
/// blank. Fully local: the share sheet just hands over a file URL.
@MainActor
enum Share {
    static func present(_ items: [Any], onComplete: (() -> Void)? = nil) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onComplete?() }
        if let pop = vc.popoverPresentationController {     // iPad anchor
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 8, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }
}

/// Create a portable encrypted backup protected by a separate backup passphrase,
/// then hand it to the share sheet (Save to Files / AirDrop / …).
struct BackupSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(loc(.backupPassphrase), text: $passphrase)
                } header: {
                    Text(loc(.backupCreateTitle))
                } footer: {
                    Text(loc(.backupHint))
                }
                Section {
                    if let error { Text(error).font(.caption).foregroundStyle(KontivaTheme.swissRed) }
                } footer: {
                    Text(loc(.backupSavedHint))
                }
            }
            .navigationTitle(loc(.settingsBackup))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc(.commonCancel)) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc(.commonSave), action: export)
                        .fontWeight(.semibold)
                        .disabled(passphrase.isEmpty || model.isWorking)
                }
            }
        }
    }

    private func export() {
        let pass = passphrase
        Task {
            guard let data = await model.makeBackupData(passphrase: pass) else {
                error = loc(.backupInvalid); return
            }
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("kontiva-\(df.string(from: Date())).kontivabackup")
            do {
                try data.write(to: url, options: [.atomic])
                Share.present([url]) { dismiss() }
            } catch { self.error = loc(.backupInvalid) }
        }
    }
}

/// Guarded restore: pick a backup file, preview its contents, then confirm the
/// destructive replace.
struct RestoreSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    @State private var showImporter = false
    @State private var fileData: Data?
    @State private var fileName: String?
    @State private var passphrase = ""
    @State private var preview: BackupPreview?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showImporter = true } label: {
                        Label(fileName ?? loc(.settingsRestore), systemImage: "doc")
                    }
                    SecureField(loc(.backupPassphrase), text: $passphrase)
                    Button(loc(.restorePreview), action: loadPreview)
                        .disabled(fileData == nil || passphrase.isEmpty || model.isWorking)
                }

                if let preview {
                    Section {
                        Text(SwissDate.medium(preview.createdAt, locale: loc.language.locale))
                            .font(.caption).foregroundStyle(KontivaTheme.textSecondary)
                        Text(summary(preview)).font(.callout).foregroundStyle(KontivaTheme.textPrimary)
                    } footer: {
                        Text(loc(.restoreWarning)).foregroundStyle(KontivaTheme.swissRed)
                    }
                    Section {
                        Button(role: .destructive, action: doRestore) {
                            Label(loc(.restoreConfirm), systemImage: "exclamationmark.triangle.fill")
                        }
                        .disabled(model.isWorking)
                    }
                }

                if let error {
                    Section { Text(error).font(.caption).foregroundStyle(KontivaTheme.swissRed) }
                }
            }
            .navigationTitle(loc(.settingsRestore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(loc(.commonCancel)) { dismiss() } }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.data, .item],
                          allowsMultipleSelection: false) { handleImport($0) }
        }
    }

    private func summary(_ p: BackupPreview) -> String {
        func n(_ key: String) -> Int { p.counts[key] ?? 0 }
        return "\(loc(.planningIncome)): \(n("incomes")) · \(loc(.planningFixed)): \(n("fixedCosts")) · \(loc(.billsTitle)): \(n("bills"))"
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url) {
            fileData = data; fileName = url.lastPathComponent; preview = nil; error = nil
        } else {
            error = loc(.backupInvalid)
        }
    }

    private func loadPreview() {
        guard let data = fileData else { return }
        let pass = passphrase
        Task {
            if let p = await model.previewBackup(data: data, passphrase: pass) {
                preview = p; error = nil
            } else {
                preview = nil; error = loc(.backupInvalid)
            }
        }
    }

    private func doRestore() {
        guard let data = fileData else { return }
        let pass = passphrase
        Task {
            let ok = await model.restoreFromBackup(data: data, passphrase: pass)
            if ok { dismiss() } else { error = loc(.backupInvalid) }
        }
    }
}
