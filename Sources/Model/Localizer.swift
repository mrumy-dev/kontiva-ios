import Foundation
import Combine
import KontivaCore

/// Observable wrapper around the shared `Localization` tables (which live in
/// KontivaCore). `loc(.key)` reads a string; changing the language republishes.
public final class Localizer: ObservableObject {
    @Published public private(set) var localization: Localization

    public init(language: AppLanguage = .deCH) {
        self.localization = Localization(language: language)
    }

    public var language: AppLanguage { localization.language }

    public func setLanguage(_ language: AppLanguage) {
        localization = Localization(language: language)
    }

    public func callAsFunction(_ key: L10nKey) -> String { localization.string(key) }
    public func string(_ key: L10nKey) -> String { localization.string(key) }
}
