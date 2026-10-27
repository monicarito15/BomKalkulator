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
                defaultsSection
                purchasesSection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
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
                    Text("Driver name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Your name", text: $driverName)
                        .font(.body)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Company")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Company name", text: $companyName)
                        .font(.body)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accountant email")
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
                Text("Report reminder")
                Spacer()
                Picker("", selection: $reportReminder) {
                    Text("Daily").tag("daily")
                    Text("Weekly").tag("weekly")
                    Text("Monthly").tag("monthly")
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text("Rest alert")
                Spacer()
                Picker("", selection: $restAlertInterval) {
                    Text("2 h").tag("2")
                    Text("3 h").tag("3")
                    Text("4 h").tag("4")
                    Text("Off").tag("off")
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text("Auto-resume")
                Spacer()
                Toggle("", isOn: $autoResume)
                    .labelsHidden()
            }
        } header: {
            Text("WORK TRIP")
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text("Used in the Work Trip tab and your PDF reports.")
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
                        
                        Text(option.rawValue)
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
            Text("APPEARANCE")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
    
    // Defaults
    private var defaultsSection: some View {
        Section {
            // Vehicle
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                Text("Vehicle")
                
                Spacer()
                
                Picker("", selection: $defaultVehicle) {
                    ForEach(VehicleType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Fuel
            HStack(spacing: 12) {
                let fuel = FuelType(rawValue: defaultFuel) ?? .gas
                Image(systemName: fuel == .electric ? "bolt.fill" : "fuelpump.fill")
                    .foregroundStyle(fuel == .electric ? .green : fuel == .diesel ? .gray : .orange)
                    .frame(width: 24)
                
                Text("Fuel")
                
                Spacer()
                
                Picker("", selection: $defaultFuel) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            
        } header: {
            Text("DEFAULTS")
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text("These will be pre-selected when you open the calculator.")
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
                    Text(isRestoring ? "Restoring..." : "Restore Purchase")
                        .foregroundStyle(.primary)
                }
            }
            .disabled(isRestoring || purchaseManager.isPremium)
        } header: {
            Text("PURCHASE")
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text(purchaseManager.isPremium ? "You have unlimited searches." : "Already purchased? Tap to restore.")
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
                    Text("Clear Search History")
                }
            }
            .alert("Clear History", isPresented: $showClearHistoryAlert) {
                Button("Clear", role: .destructive) {
                    let items = (try? modelContext.fetch(FetchDescriptor<SearchHistoryItem>())) ?? []
                    items.forEach { modelContext.delete($0) }
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All search history will be deleted. This cannot be undone.")
            }
        } header: {
            Text("DATA")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    //  About
    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text("Version")

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
                    Text("Report a Bug")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("ABOUT")
                .font(.caption)
                .fontWeight(.semibold)
        } footer: {
            Text("Found a bug? Send us an email and we'll fix it.")
                .font(.caption2)
        }
    }
}

#Preview {
    SettingsView()
}
