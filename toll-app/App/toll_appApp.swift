import SwiftUI
import SwiftData

@main
struct toll_appApp: App {

    let modelContainer: ModelContainer
    @StateObject private var purchaseManager = PurchaseManager()
    
    init() {
        let schema = Schema([
            Vegobjekt.self,
            Egenskap.self,
            Lokasjon.self,
            Geometri.self,
            RecentSearch.self,
            SearchHistoryItem.self,
            FeeCalculation.self,
            WorkTrip.self
        ])
        
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            // If the database is corrupted, delete it and try again
            #if DEBUG
            print("SwiftData failed to load: \(error). Attempting to reset.")
            #endif
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .modelContainer(modelContainer)
                .environmentObject(purchaseManager)
        }
    }
}

