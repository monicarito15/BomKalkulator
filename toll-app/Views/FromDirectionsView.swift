import SwiftUI
import MapKit
import SwiftData

struct FromDirectionsView: View {

    @StateObject private var viewModel = SearchAddressViewModel()

    @Binding var searchText: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    @Binding var isFromCurrentLocation: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var locationManager = LocationManager()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                List {
                    Section {
                        yourLocationRow
                    }

                    if !viewModel.completions.isEmpty && !searchText.isEmpty {
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
                            ForEach(viewModel.recentSearches, id: \.self) { item in
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
            .navigationTitle("Starting Point")
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isSearchFocused = true
                }
            }
            .task {
                await viewModel.loadRecentSearch(using: modelContext)
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search starting point...", text: $searchText)
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
    
    // MARK: - Your Location Row
    private var yourLocationRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundStyle(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Location")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                
                if let address = locationManager.currentAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFromCurrentLocation = true
            if let address = locationManager.currentAddress {
                searchText = address
            } else if let location = locationManager.userLocation {
                searchText = String(format: "%.4f, %.4f", location.latitude, location.longitude)
            }
            locationManager.requestLocation()
            dismiss()
        }
    }
    
    // MARK: - Rows
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
            viewModel.completions = []
            dismiss()
            Task {
                await viewModel.saveSearch(item.name, address: item.address, using: modelContext)
            }
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
    
    // MARK: - Actions
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
