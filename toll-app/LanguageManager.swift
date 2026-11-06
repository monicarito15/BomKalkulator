import SwiftUI

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    private init() {}

    @AppStorage("appLanguage") var languageCode: String = "nb" {
        willSet { objectWillChange.send() }
    }

    var isNorwegian: Bool { languageCode == "nb" }

    func t(nb: String, en: String) -> String {
        isNorwegian ? nb : en
    }
}
