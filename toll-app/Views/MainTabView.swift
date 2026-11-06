import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showSheet = false
    @State private var selectedTab = 0
    @State private var didAppearOnce = false // para saber si ya se abrio el sheet alguna vez

    @State private var currentDetent: PresentationDetent = .height(460) // padre del estado del tamano global

    @State private var selectedHistoryItem: SearchHistoryItem? = nil // para rehacer una búsqueda

    @AppStorage("appAppearance") private var appearance: String = AppAppearance.automatic.rawValue




    var body: some View {
        //logica para resetear el sheet si ya esta abierto
        let tabBinding = Binding<Int>(
            get: { selectedTab },
            set: { newValue in
                if newValue == 1 && selectedTab == 1 {
                    showSheet = false
                }
                selectedTab = newValue
            }
        )
        TabView(selection: tabBinding) {
            OversiktView(onShowHistory: { selectedTab = 2 })
                .tabItem {
                    Label(lang.t(nb: "Oversikt", en: "Overview"), systemImage: "doc.text.fill")
                }
            
                .tag(0)
            HistoryView(onSelectSearch: { historyItem in
                selectedHistoryItem = historyItem
                selectedTab = 1
            })
            .environmentObject(purchaseManager)
                .tabItem {
                    Label(lang.t(nb: "Historikk", en: "History"), systemImage: "car.fill")
                }
            
                .tag(1)
            TravelView(showSheet: $showSheet,
                       currentDetent: $currentDetent,
                       selectedHistoryItem: $selectedHistoryItem
            )
                .tabItem {
                    Label(lang.t(nb: "Reise", en: "Travel"), systemImage: "magnifyingglass.circle.fill")
                }
            
                .tag(2)
            WorkTripView()
                .tabItem {
                    Label(lang.t(nb: "Kjøretur", en: "Work Trip"), systemImage: "steeringwheel")
                }
            
                .tag(3)
            SettingsView()
                .tabItem {
                    Label(lang.t(nb: "Innst.", en: "Settings"), systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
#Preview {
    MainTabView()
}
