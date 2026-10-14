import Foundation
import SwiftUI
import Observation
import Synchronization

/// Localizes display values whose original English identifiers must remain stable.
nonisolated enum L10n {
    static var bundle: Bundle {
        let identifier = LanguageSettings.shared.language.identifier
        return bundles[identifier] ?? .main
    }

    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: ["en", "zh-Hans"].compactMap { identifier in
        Bundle.main.path(forResource: identifier, ofType: "lproj")
            .flatMap(Bundle.init(path:)).map { (identifier, $0) }
    })

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

nonisolated enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var title: String {
        switch self {
        case .system: String(localized: "System Default", bundle: L10n.bundle)
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }

    static var current: AppLanguage {
        guard let identifier = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: identifier)?["AppleLanguages"] as? [String],
              let first = languages.first else { return .system }
        if first.hasPrefix("en") { return .english }
        if first == "zh-Hans" || first.hasPrefix("zh-Hans-") || first == "zh-CN" || first == "zh-SG" {
            return .simplifiedChinese
        }
        return .system
    }

    var identifier: String {
        guard self == .system else { return rawValue }
        let preferences = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferences ?? Locale.preferredLanguages).first ?? "en"
    }
}

/// String lookups also run in background import and export work.
@Observable
nonisolated final class LanguageSettings: Sendable {
    static let shared = LanguageSettings()
    @ObservationIgnored private let selection = Mutex(AppLanguage.current)

    var language: AppLanguage {
        get {
            access(keyPath: \.language)
            return selection.withLock { $0 }
        }
        set {
            withMutation(keyPath: \.language) { selection.withLock { $0 = newValue } }
        }
    }

    @MainActor func select(_ option: AppLanguage) {
        if option == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([option.rawValue], forKey: "AppleLanguages")
        }
        language = option
        DispatchQueue.main.async { CompositorApplicationDelegate.refreshMenuLanguage() }
    }
}

private struct LocalizedInterface: ViewModifier {
    var onChange: (() -> Void)?
    func body(content: Content) -> some View {
        let language = LanguageSettings.shared.language
        content.environment(\.locale, Locale(identifier: language.identifier))
            .onChange(of: language) { _, _ in onChange?() }
    }
}

extension View {
    func localizedInterface(onChange: (() -> Void)? = nil) -> some View {
        modifier(LocalizedInterface(onChange: onChange))
    }
}
