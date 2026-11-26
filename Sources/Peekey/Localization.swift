import Foundation

/// In-app UI language. Switching takes effect immediately (no restart), independent of the system language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// Always shown in its own language so users can find their way back.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    static var current: AppLanguage = .english
}

/// Returns the string for the current UI language. Both variants live side by side at the call site
/// so a missing translation is impossible and copy stays easy to review.
func L(_ en: String, _ zh: String) -> String {
    AppLanguage.current == .simplifiedChinese ? zh : en
}

import SwiftUI

/// Rebuilds its content whenever the UI language changes, so every `L(...)` is re-evaluated live.
struct LocalizedRoot<Content: View>: View {
    @EnvironmentObject private var settings: Settings
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().id(settings.language)
    }
}
