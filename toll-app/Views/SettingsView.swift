import SwiftUI
import SwiftData

enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .automatic: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("appAppearance") private var appearance: String = AppAppearance.automatic.rawValue
    @AppStorage("defaultVehicle") private var defaultVehicle: String = VehicleType.car.rawValue
    @AppStorage("defaultFuel") private var defaultFuel: String = FuelType.gas.rawValue
    @AppStorage("driverName") private var driverName: String = ""
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("accountantEmail") private var accountantEmail: String = ""
    @AppStorage("reportReminder") private var reportReminder: String = "weekly"
    @AppStorage("restAlertInterval") private var restAlertInterval: String = "3"
    @AppStorage("autoResume") private var autoResume: Bool = true
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var showClearHistoryAlert = false
    @State private var isRestoring = false

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearance) ?? .automatic
    }

    var body: some View {
        NavigationView {
            List {
                workTripSection
                appearanceSection
                languageSection
                defaultsSection
                purchasesSection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(lang.t(nb: "Innstillinger", en: "Settings"))
        }
    }

    // Work Trip
    private var workTripSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(nb: "Sjåførnavn", en: "Driver name"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(lang.t(nb: "Ditt navn", en: "Your name"), text: $driverName)
                        .font(.body)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(nb: "Selskap", en: "Company"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(lang.t(nb: "Selskapsnavn", en: "Company name"), text: $companyName)
                        .font(.body)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(nb: "Regnskapsførerens e-post", en: "Accountant email"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("email@example.com", text: $accountantEmail)
                        .font(.body)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(lang.t(nb: "Rapportpåminnelse", en: "Report reminder"))
                Spacer()
                Picker("", selection: $reportReminder) {
                    Text(lang.t(nb: "Daglig", en: "Daily")).tag("daily")
                    Text(lang.t(nb: "Ukentlig", en: "Weekly")).tag("weekly")
                    Text(lang.t(nb: "Månedlig", en: "Monthly")).tag("monthly")
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(lang.t(nb: "Hvilevarsel", en: "Rest alert"))
                Spacer()
                Picker("", selection: $restAlertInterval) {
                    Text("2 h").tag("2")
                    Text("3 h").tag("3")
                    Text("4 h").tag("4")
                    Text(lang.t(nb: "Av", en: "Off")).tag("off")
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(lang.t(nb: "Gjenoppta automatisk", en: "Auto-resume"))
                Spacer()
                Toggle("", isOn: $autoResume)
                    .labelsHidden()
            }
        } header: {
            Text(lang.t(nb: "KJØRETUR", en: "WORK TRIP"))
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text(lang.t(nb: "Brukes i Kjøretur-fanen og PDF-rapportene dine.", en: "Used in the Work Trip tab and your PDF reports."))
                .font(.caption2)
        }
    }

    // Appearance
    private var appearanceSection: some View {
        Section {
            ForEach(AppAppearance.allCases) { option in
                Button {
                    appearance = option.rawValue
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.icon)
                            .foregroundStyle(option == selectedAppearance ? .blue : .secondary)
                            .frame(width: 24)

                        Text(localizedAppearance(option))
                            .foregroundStyle(.primary)

                        Spacer()

                        if option == selectedAppearance {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        } header: {
            Text(lang.t(nb: "UTSEENDE", en: "APPEARANCE"))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    private func localizedAppearance(_ option: AppAppearance) -> String {
        switch option {
        case .automatic: return lang.t(nb: "Automatisk", en: "Automatic")
        case .light: return lang.t(nb: "Lys", en: "Light")
        case .dark: return lang.t(nb: "Mørk", en: "Dark")
        }
    }

    // Language
    private var languageSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(lang.t(nb: "Språk", en: "Language"))
                Spacer()
                Picker("", selection: Binding(
                    get: { LanguageManager.shared.languageCode },
                    set: { LanguageManager.shared.languageCode = $0 }
                )) {
                    Text("Norsk 🇳🇴").tag("nb")
                    Text("English 🇬🇧").tag("en")
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("LANGUAGE / SPRÅK")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    // Defaults
    private var defaultsSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text(lang.t(nb: "Kjøretøy", en: "Vehicle"))

                Spacer()

                Picker("", selection: $defaultVehicle) {
                    ForEach(VehicleType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                let fuel = FuelType(rawValue: defaultFuel) ?? .gas
                Image(systemName: fuel == .electric ? "bolt.fill" : "fuelpump.fill")
                    .foregroundStyle(fuel == .electric ? .green : fuel == .diesel ? .gray : .orange)
                    .frame(width: 24)

                Text(lang.t(nb: "Drivstoff", en: "Fuel"))

                Spacer()

                Picker("", selection: $defaultFuel) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

        } header: {
            Text(lang.t(nb: "STANDARDVERDIER", en: "DEFAULTS"))
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text(lang.t(nb: "Disse velges automatisk når du åpner kalkulatoren.", en: "These will be pre-selected when you open the calculator."))
                .font(.caption2)
        }
    }

    // Purchases
    private var purchasesSection: some View {
        Section {
            Button {
                Task {
                    isRestoring = true
                    await purchaseManager.restorePurchases()
                    isRestoring = false
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text(isRestoring ? lang.t(nb: "Gjenoppretter...", en: "Restoring...") : lang.t(nb: "Gjenopprett kjøp", en: "Restore Purchase"))
                        .foregroundStyle(.primary)
                }
            }
            .disabled(isRestoring || purchaseManager.isPremium)
        } header: {
            Text(lang.t(nb: "KJØP", en: "PURCHASE"))
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text(purchaseManager.isPremium
                 ? lang.t(nb: "Du har ubegrensede søk.", en: "You have unlimited searches.")
                 : lang.t(nb: "Allerede kjøpt? Trykk for å gjenopprette.", en: "Already purchased? Tap to restore."))
                .font(.caption2)
        }
    }

    // Data
    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showClearHistoryAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    Text(lang.t(nb: "Slett søkehistorikk", en: "Clear Search History"))
                }
            }
            .alert(lang.t(nb: "Slett historikk", en: "Clear History"), isPresented: $showClearHistoryAlert) {
                Button(lang.t(nb: "Slett", en: "Clear"), role: .destructive) {
                    let items = (try? modelContext.fetch(FetchDescriptor<SearchHistoryItem>())) ?? []
                    items.forEach { modelContext.delete($0) }
                    try? modelContext.save()
                }
                Button(lang.t(nb: "Avbryt", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(lang.t(nb: "All søkehistorikk slettes. Dette kan ikke angres.", en: "All search history will be deleted. This cannot be undone."))
            }
        } header: {
            Text(lang.t(nb: "DATA", en: "DATA"))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    // About
    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text(lang.t(nb: "Versjon", en: "Version"))

                Spacer()

                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }

            Button {
                let email = "carolinamera1985@gmail.com"
                let subject = "BomKalkulator - Feilrapport"
                let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 24)
                    Text(lang.t(nb: "Rapporter en feil", en: "Report a Bug"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text(lang.t(nb: "OM", en: "ABOUT"))
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text(lang.t(nb: "Funnet en feil? Send oss en e-post så fikser vi det.", en: "Found a bug? Send us an email and we'll fix it."))
                .font(.caption2)
        }
    }
}
