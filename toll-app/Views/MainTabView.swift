import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var showSheet = false
    @State private var selectedTab = 0
    @State private var didAppearOnce = false // para saber si ya se abrio el sheet alguna vez
    
    @State private var currentDetent: PresentationDetent = .height(460) // padre del estado del tamano global
   
    @State private var selectedHistoryItem: SearchHistoryItem? = nil // para rehacer una búsqueda
    
    @AppStorage("appAppearance") private var appearance: String = AppAppearance.automatic.rawValue




    var body: some View {
        //logica para resetear el sheet si ya esta abierto
        let tabBinding = Binding<Int>( // Create a binding to monitor tab changes
            get: { selectedTab },
            set: { newValue in
                if newValue == 0 {
                    if didAppearOnce {
                        showSheet = false // cierra el sheet si ya se habia abierto antes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // espera 0.1 segundos para que el swiftui tenga para procesar el cambio de tab
                            showSheet = true
                            
                        }
                    } else {
                        showSheet = true // la primera vez que se abre el tab, abre el sheet
                        didAppearOnce = true
                    }
                }
                selectedTab = newValue
            }
        )
        TabView(selection: tabBinding) {
            TravelView(showSheet: $showSheet,
                       currentDetent: $currentDetent,
                       selectedHistoryItem: $selectedHistoryItem
            )
                .tabItem {
                    Label("Travel", systemImage: "magnifyingglass.circle.fill")
                }
                .tag(0)

            HistoryView(onSelectSearch: { historyItem in
                selectedHistoryItem = historyItem
                selectedTab = 0
            })
            .environmentObject(purchaseManager)
                .tabItem {
                    Label("History", systemImage: "car.fill")
                }
                .tag(1)

            WorkTripView()
                .tabItem {
                    Label("Work Trip", systemImage: "steeringwheel")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}
#Preview {
    MainTabView()
}
