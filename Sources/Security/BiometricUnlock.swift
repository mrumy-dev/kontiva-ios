import Foundation
import LocalAuthentication
import Security

/// Which biometric the device offers.
enum BiometricKind {
    case faceID, touchID, opticID, none

    var label: String {
        switch self {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none:    return ""
        }
    }
    var icon: String {
        switch self {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none:    return "lock"
        }
    }
    var isAvailable: Bool { self != .none }
}

enum Biometrics {
    /// The biometric the device currently has enrolled and available.
    static var kind: BiometricKind {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return .none }
        switch ctx.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default:       return .none
        }
    }
}

/// Stores the vault passphrase in the Keychain as a *convenience* layer over the
/// passphrase: retrieval is gated by an explicit Face ID / Touch ID check
/// (`LAContext.evaluatePolicy`). The passphrase stays the root secret, the
/// no-recovery guarantee is unchanged, and the item never leaves the device
/// (`...ThisDeviceOnly`, no iCloud sync, protected when the device is locked).
///
/// NOTE: the biometric gate here is enforced in-app, not by the Secure Enclave —
/// a deliberate trade-off so the feature works without a device passcode (the
/// Simulator can't set one). Production hardening: bind the item to the Secure
/// Enclave with a `.biometryCurrentSet` `SecAccessControl`, which requires a
/// passcode (always present on real devices that have Face ID).
enum BiometricVault {
    private static let service = "ch.kontiva.ios.biometric-passphrase"
    private static let account = "vault"

    /// Is a passphrase stored? (No biometric prompt — plain presence check.)
    static var hasStored: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func store(passphrase: String) -> Bool {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(passphrase.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Prompts for biometrics, and on success returns the stored passphrase.
    static func retrieve(reason: String) async -> String? {
        let ctx = LAContext()
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            guard ok else { return nil }
        } catch {
            return nil
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
