import Foundation

/// Text from the String Catalog by key, for ViewModels that format text. Keys are the Android string names.
nonisolated enum Strings {
    static func text(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// The string with its placeholders filled in (%1$@ for text, %1$lld for whole numbers).
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: arguments)
    }

    /// A plural string ("1 set", "3 sets", in Ukrainian "3 підходи", "5 підходів") for [count].
    static func plural(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(text(key), count)
    }
}
