import SwiftUI
import SwiftData

struct AccountSettingsView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("appAppearance") private var appearance: String = AppAppearance.automatic.rawValue
    @AppStorage("reportReminder") private var reportReminder: String = "weekly"
    @AppStorage("restAlertInterval") private var restAlertInterval: String = "3"
    @AppStorage("autoResume") private var autoResume: Bool = true
    @Environment(\.modelContext) private var modelContext
    @State private var showClearHistoryAlert = false

    private func localizedAppearance(_ option: AppAppearance) -> String {
        switch option {
        case .automatic: return lang.t(nb: "Automatisk", en: "Automatic")
        case .light: return lang.t(nb: "Lys", en: "Light")
        case .dark: return lang.t(nb: "Mørk", en: "Dark")
        }
    }

    var body: some View {
        List {
            Section(lang.t(nb: "UTSEENDE", en: "APPEARANCE")) {
                Picker(lang.t(nb: "Utseende", en: "Appearance"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(localizedAppearance(option)).tag(option.rawValue)
                    }
                }
                Picker(lang.t(nb: "Språk", en: "Language"), selection: Binding(
                    get: { LanguageManager.shared.languageCode },
                    set: { LanguageManager.shared.languageCode = $0 }
                )) {
                    Text("Norsk 🇳🇴").tag("nb")
                    Text("English 🇬🇧").tag("en")
                }
            }

            Section(lang.t(nb: "KJØRETUR", en: "WORK TRIP")) {
                Picker(lang.t(nb: "Rapportpåminnelse", en: "Report reminder"), selection: $reportReminder) {
                    Text(lang.t(nb: "Daglig", en: "Daily")).tag("daily")
                    Text(lang.t(nb: "Ukentlig", en: "Weekly")).tag("weekly")
                    Text(lang.t(nb: "Månedlig", en: "Monthly")).tag("monthly")
                }
                Picker(lang.t(nb: "Hvilevarsel", en: "Rest alert"), selection: $restAlertInterval) {
                    Text("2 h").tag("2")
                    Text("3 h").tag("3")
                    Text("4 h").tag("4")
                    Text(lang.t(nb: "Av", en: "Off")).tag("off")
                }
                Toggle(lang.t(nb: "Gjenoppta automatisk", en: "Auto-resume"), isOn: $autoResume)
            }

            Section(lang.t(nb: "DATA", en: "DATA")) {
                Button(role: .destructive) {
                    showClearHistoryAlert = true
                } label: {
                    Label(lang.t(nb: "Slett søkehistorikk", en: "Clear Search History"),
                          systemImage: "trash.fill")
                }
                .alert(lang.t(nb: "Slett historikk", en: "Clear History"), isPresented: $showClearHistoryAlert) {
                    Button(lang.t(nb: "Slett", en: "Clear"), role: .destructive) {
                        let items = (try? modelContext.fetch(FetchDescriptor<SearchHistoryItem>())) ?? []
                        items.forEach { modelContext.delete($0) }
                        try? modelContext.save()
                    }
                    Button(lang.t(nb: "Avbryt", en: "Cancel"), role: .cancel) {}
                } message: {
                    Text(lang.t(nb: "All søkehistorikk slettes. Dette kan ikke angres.",
                                en: "All search history will be deleted. This cannot be undone."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lang.t(nb: "Innstillinger", en: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
