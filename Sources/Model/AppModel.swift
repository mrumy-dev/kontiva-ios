import SwiftUI
import KontivaCore
import KontivaPersistence

/// The iOS app model: owns the lock gate and the decrypted dataset, backed by the
/// shared `EncryptedStore` actor. Platform-specific bits (auto-lock on background,
/// biometrics) layer on later — this is the foundation the screens bind to.
@MainActor
final class AppModel: ObservableObject {
    enum LockState: Equatable { case needsSetup, locked, unlocked }

    @Published private(set) var lockState: LockState
    @Published private(set) var dataset: AppDataset = .empty
    @Published var isWorking = false

    private let store: EncryptedStore

    init() {
        // Encrypted store lives in the app's Application Support sandbox.
        let location = (try? StoreLocation.applicationSupport())
            ?? StoreLocation(directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("Kontiva", isDirectory: true))
        let store = EncryptedStore(location: location)
        self.store = store
        self.lockState = store.hasExistingVault() ? .locked : .needsSetup
    }

    /// First run: create the vault under this passphrase. No recovery by design.
    func setUp(passphrase: String) async {
        guard !passphrase.isEmpty else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try await store.createVault(passphrase: passphrase)
            dataset = (try? await store.snapshot()) ?? .empty
            lockState = .unlocked
        } catch {
            // e.g. a vault already exists; stay on setup.
        }
    }

    /// Returns true on success, false on a wrong passphrase (AES-GCM auth failure).
    @discardableResult
    func unlock(passphrase: String) async -> Bool {
        isWorking = true; defer { isWorking = false }
        do {
            try await store.unlock(passphrase: passphrase)
            dataset = (try? await store.snapshot()) ?? .empty
            lockState = .unlocked
            return true
        } catch {
            return false
        }
    }

    func lock() async {
        await store.lock()
        dataset = .empty
        lockState = .locked
    }

    var hasFinancialData: Bool { dataset.hasFinancialData }
}
