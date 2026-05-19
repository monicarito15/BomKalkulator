import SwiftUI
import MapKit
import SwiftData

struct ToDirectionsView: View {

    @StateObject private var viewModel = SearchAddressViewModel()

    @Binding var searchText: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var isFromCurrentLocation: Bool
    @StateObject private var locationManager = LocationManager()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                List {
                    if !viewModel.completions.isEmpty {
                        Section {
                            ForEach(viewModel.completions, id: \.self) { completion in
                                completionRow(completion)
                            }
                        } header: {
                            Text("SUGGESTIONS")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }

                    if !viewModel.recentSearches.isEmpty && searchText.isEmpty {
                        Section {
                            ForEach(viewModel.recentSearches) { item in
                                recentRow(item)
                            }
                        } header: {
                            Text("RECENT")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))
            .navigationTitle("Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                searchText = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4){
                    isSearchFocused = true
                }
            }
            .task {
                await viewModel.loadRecentSearch(using: modelContext)
            }
        }
    }
    
    // Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search destination...", text: $searchText)
                .focused($isSearchFocused)
                .onSubmit {
                    if let first = viewModel.completions.first {
                        selectCompletion(first)
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    viewModel.searchAddresses(query: newValue)
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(.systemGray5) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    //  Rows
    private func completionRow(_ completion: MKLocalSearchCompletion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.title)
                    .font(.subheadline.weight(.medium))
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = false
            selectCompletion(completion)
        }
    }

    private func recentRow(_ item: RecentSearch) -> some View {
        Button {
            isSearchFocused = false
            searchText = item.address
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                    Text(item.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    

    // Resuelve la sugerencia a coordenadas reales antes de cerrar la vista
    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        Task {
            guard let item = await viewModel.resolveCompletion(completion) else { return }
            let name = completion.title
            let address = [completion.title, completion.subtitle]
                .filter { !$0.isEmpty }.joined(separator: ", ")
            searchText = address
            selectedCoordinate = item.placemark.coordinate
            viewModel.completions = []
            dismiss()
            await viewModel.saveSearch(name, address: address, using: modelContext)
        }
    }
}
