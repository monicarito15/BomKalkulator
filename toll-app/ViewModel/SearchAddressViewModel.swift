//
//  SearchAddressViewModel.swift
//  toll-app
//
//  Created by Carolina Mera  on 20/10/2025.
//

import SwiftUI
import MapKit
import SwiftData

// NSObject es requerido para implementar MKLocalSearchCompleterDelegate
@MainActor
final class SearchAddressViewModel: NSObject, ObservableObject {

    // Sugerencias de autocompletado — se actualizan con cada letra
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var recentSearches: [RecentSearch] = []
    @Published var searchQuery: String = ""

    private let completer = MKLocalSearchCompleter()
    private var debounceTask: Task<Void, Never>?

    override init() {
        super.init()
        completer.delegate = self

        // Bounding box de Noruega: lat 57.5–71.5, lon 4–32
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 64.5, longitude: 17.0),
            span: MKCoordinateSpan(latitudeDelta: 14.0, longitudeDelta: 28.0)
        )
        completer.resultTypes = [.address, .pointOfInterest]
    }

    // Actualiza el fragmento del completer con debounce de 300ms para no saturar MapKit
    func searchAddresses(query: String) {
        searchQuery = query
        debounceTask?.cancel()
        if query.isEmpty {
            completions = []
            completer.cancel()
            return
        }
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            completer.queryFragment = query
        }
    }

    // Cuando el usuario elige una sugerencia, resuelve a MKMapItem para obtener coordenadas
    func resolveCompletion(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        request.region = completer.region
        do {
            let response = try await MKLocalSearch(request: request).start()
            // Prefiere resultados noruegos, pero acepta el primero si no hay
            return response.mapItems.first(where: { $0.placemark.countryCode == "NO" })
                ?? response.mapItems.first
        } catch {
            return nil
        }
    }

    func saveSearch(_ name: String, address: String, using context: ModelContext) async {
        guard !name.isEmpty else { return }

        let descriptor = FetchDescriptor<RecentSearch>()
        let allSearches = (try? context.fetch(descriptor)) ?? []

        if let existing = allSearches.first(where: {
            $0.name.lowercased() == name.lowercased() &&
            $0.address.lowercased() == address.lowercased()
        }) {
            context.delete(existing)
        }

        let newSearch = RecentSearch(name: name, address: address)
        context.insert(newSearch)

        do {
            try context.save()
            await loadRecentSearch(using: context)

            let allAfterSave = (try? context.fetch(FetchDescriptor<RecentSearch>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            ))) ?? []

            if allAfterSave.count > 5 {
                for old in Array(allAfterSave.dropFirst(5)) {
                    context.delete(old)
                }
                try context.save()
                await loadRecentSearch(using: context)
            }
        } catch {
            #if DEBUG
            print("Error saving search: \(error)")
            #endif
        }
    }

    func loadRecentSearch(using context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<RecentSearch>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let fetched = try context.fetch(descriptor)

            var seen = Set<String>()
            recentSearches = fetched.filter { search in
                let key = "\(search.name.lowercased())|\(search.address.lowercased())"
                return seen.insert(key).inserted
            }.prefix(5).map { $0 }
        } catch {
            #if DEBUG
            print("Error fetching recent searches: \(error)")
            #endif
        }
    }
}

// Delegate fuera del actor para evitar warnings de concurrencia
extension SearchAddressViewModel: MKLocalSearchCompleterDelegate {

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Keep only Norwegian results — subtitle for NO addresses includes "Norway" or "Norge"
        let results = completer.results.filter {
            let sub = $0.subtitle.lowercased()
            return sub.contains("norway") || sub.contains("norge") || sub.isEmpty
        }
        Task { @MainActor in
            self.completions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.completions = []
        }
    }
}
