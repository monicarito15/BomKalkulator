import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @State private var showSheet = false
    @State private var selectedTab = 0

    @State private var currentDetent: PresentationDetent = .height(520)
    @State private var selectedHistoryItem: SearchHistoryItem? = nil

    @AppStorage("appAppearance") private var appearance: String = AppAppearance.automatic.rawValue

    var body: some View {
        let tabBinding = Binding<Int>(
            get: { selectedTab },
            set: { newValue in
                if newValue == 1 && selectedTab == 1 { showSheet = false }
                selectedTab = newValue
            }
        )

        ZStack {
            TabView(selection: tabBinding) {
                OversiktView(onShowHistory: { selectedTab = 2 })
                    .tabItem {
                        Label(lang.t(nb: "Oversikt", en: "Overview"), systemImage: "doc.text.fill")
                    }
                    .tag(0)

                WorkTripView()
                    .tabItem {
                        Label(lang.t(nb: "Kjøretur", en: "Work Trip"), systemImage: "steeringwheel")
                    }
                    .tag(1)

                TravelView(showSheet: $showSheet,
                           currentDetent: $currentDetent,
                           selectedHistoryItem: $selectedHistoryItem)
                    .tabItem {
                        Label(lang.t(nb: "Reise", en: "Travel"), systemImage: "magnifyingglass.circle.fill")
                    }
                    .tag(2)

                HistoryView(onSelectSearch: { historyItem in
                    selectedHistoryItem = historyItem
                    selectedTab = 2
                })
                .environmentObject(purchaseManager)
                    .tabItem {
                        Label(lang.t(nb: "Historikk", en: "History"), systemImage: "car.fill")
                    }
                    .tag(3)
            }
            .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: .openWorkTripTab)) { _ in
                selectedTab = 1
            }

            if appState.showAccountPanel {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            appState.showAccountPanel = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                AccountPanel()
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: appState.showAccountPanel)
    }
}

#Preview {
    MainTabView()
}
