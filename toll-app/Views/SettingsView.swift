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
    @AppStorage("defaultAutopass") private var defaultAutopass: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var showClearHistoryAlert = false
    
    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearance) ?? .automatic
    }
    
    var body: some View {
        NavigationView {
            List {
                appearanceSection
                defaultsSection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
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
            
            // AutoPass
            HStack(spacing: 12) {
                Image(systemName: defaultAutopass ? "checkmark.shield.fill" : "shield.slash.fill")
                    .foregroundStyle(defaultAutopass ? .blue : .secondary)
                    .frame(width: 24)
                
                Toggle("AutoPass", isOn: $defaultAutopass)
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
                let email = "apps.carolina.support@gmail.com"
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
