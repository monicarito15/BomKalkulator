//
//  MapView.swift
//  toll-app
//
//  Created by Carolina Mera on 09/10/2025.

import SwiftUI
import MapKit
import CoreLocation
import ArcGIS

struct MapView: View {

    let from: String
    let to: String
    let fromCoordinate: CLLocationCoordinate2D?
    let toCoordinate: CLLocationCoordinate2D?
    let vehicleType: VehicleType
    let fuelType: FuelType
    let dateTime: Date
    let hasAutopass: Bool

    // ViewModel compartido con TravelView, contiene rutas, tolls y lógica de ubicación
    @ObservedObject var mapVM: MapViewModel
    @StateObject private var tollStorageVM = TollStorageViewModel()
    @Environment(\.modelContext) private var modelContext

    @StateObject private var feeVM = FeeViewModel()
    @StateObject private var feeStorageVM = FeeStorageViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showDetailsSheet = false
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var selectedToll: TollCharge?

    var body: some View {
        VStack {
            ZStack {
                mapContent

                // UI overlays — solo visibles cuando hay resultado calculado
                if mapVM.hasResult {
                    summaryOverlay

                    navigationButtonOverlay
                }

                // Loading overlay mientras se calcula la ruta
                if mapVM.isLoadingRoute {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        Text("Calculating route...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 8)
                }

                // Popup de detalle al tocar un toll marker
                if selectedToll != nil {
                    TollDetailPopup(selectedToll: $selectedToll)
                }
            }
            .animation(.easeInOut, value: mapVM.hasResult)
        }
        .onAppear {
            mapVM.updateUserLocation()
            Task {
                await tollStorageVM.loadTolls(using: modelContext)
                await tollStorageVM.updateTollsIfNeeded(using: modelContext)
                mapVM.toll = tollStorageVM.tolls
            }
        }

        // Cuando llegan rutas nuevas: mueve cámara para ver todas y construye resultado
        .onChange(of: mapVM.routes) { _, newRoutes in
            guard !newRoutes.isEmpty else { return }
            selectedToll = nil

            // Calcula rect que engloba TODAS las rutas alternativas
            let fullRect = newRoutes.reduce(MKMapRect.null) { $0.union($1.polyline.boundingMapRect) }
            var rect = fullRect.insetBy(dx: -1200, dy: -1200)
            let minSide: Double = 3000
            if rect.size.width < minSide {
                rect = rect.insetBy(dx: -(minSide - rect.size.width) / 2, dy: -(minSide - rect.size.width) / 2)
            }
            withAnimation(.easeInOut) { cameraPosition = .rect(rect) }

            mapVM.buildResultIfPossible(vehicle: vehicleType, fuel: fuelType, date: dateTime)
        }

        // Cuando el usuario cambia de ruta: recalcula tolls y precio para la nueva ruta
        .onChange(of: mapVM.selectedRouteIndex) { _, _ in
            mapVM.buildResultIfPossible(vehicle: vehicleType, fuel: fuelType, date: dateTime)
        }

        // Seguridad: si los tolls de NVDB llegan después de la ruta, recalcula
        .onChange(of: mapVM.toll.count) { _, count in
            guard count > 0, mapVM.route != nil else { return }
            mapVM.buildResultIfPossible(vehicle: vehicleType, fuel: fuelType, date: dateTime)
        }

        // Cuando cambian los tolls en ruta: calcula precios desde NVDB egenskaper
        .onChange(of: mapVM.tollsOnRoute) { _, tolls in
            feeVM.hasAutoPassAgreement = hasAutopass
            feeVM.loadOrCalculateFees(
                tollsOnRoute: tolls,
                from: from,
                to: to,
                vehicle: vehicleType,
                fuel: fuelType,
                date: dateTime,
                modelContext: modelContext,
                storage: feeStorageVM,
                originCoordinate: mapVM.originCoordinate,
                destinationCoordinate: mapVM.destinationCoordinate
            )
        }

        .sheet(isPresented: $showDetailsSheet) {
            TollPassedListView(
                tollCharges: feeVM.tollCharges,
                route: mapVM.route,
                fromAddress: from,
                toAddress: to,
                vehicleType: vehicleType,
                selectedDetent: sheetDetent
            )
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.visible)
        }
    }

    // Map Content

    private var mapContent: some View {
        // MapReader convierte el punto de pantalla a coordenada geográfica para detectar tap en polyline
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let userLocation = mapVM.userLocation {
                    Marker("My location", coordinate: userLocation)
                }

                // Rutas no seleccionadas: borde cyan fosforescente + gris encima — visible en dark mode
                ForEach(Array(mapVM.routes.enumerated()), id: \.offset) { index, route in
                    if index != mapVM.selectedRouteIndex {
                        MapPolyline(route.polyline)
                            .stroke(Color.cyan.opacity(0.9), lineWidth: 8)
                        MapPolyline(route.polyline)
                            .stroke(Color(white: 0.55), lineWidth: 5)
                    }
                }

                // Ruta seleccionada: azul fuerte y más gruesa — encima de todo
                if let selected = mapVM.route {
                    MapPolyline(selected.polyline)
                        .stroke(.blue, lineWidth: 6)
                }

                // Callout de tiempo sobre la ruta seleccionada — burbuja con triángulo apuntando a la línea
                if let selected = mapVM.route,
                   let midCoord = polylineMidpoint(selected.polyline) {
                    Annotation("", coordinate: midCoord, anchor: .bottom) {
                        VStack(spacing: 0) {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text(routeTimeText(selected))
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Triángulo apuntando hacia abajo — "ganchito" que señala la línea
                            Triangle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 6)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 3)
                    }
                }

                // Markers naranjas de cada toll con precio
                ForEach(feeVM.tollCharges) { charge in
                    if let lat = charge.latitude, let lon = charge.longitude {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Button { selectedToll = charge } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 32, height: 32)
                                        .shadow(color: .black.opacity(0.3), radius: 3)
                                    Image(systemName: "norwegiankronesign")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
            }
            .tint(.blue)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .mapStyle(.standard(elevation: .realistic))
            // Tap en el mapa: detecta si el usuario tocó una ruta no seleccionada
            .onTapGesture { screenPoint in
                guard mapVM.routes.count > 1,
                      let coord = proxy.convert(screenPoint, from: .local),
                      let coordOffset = proxy.convert(CGPoint(x: screenPoint.x + 44, y: screenPoint.y), from: .local) else { return }

                let tapLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                // Threshold adapts to zoom: 44pt (finger width) in current map scale, min 200m
                let fingerWidthMeters = tapLocation.distance(from: CLLocation(latitude: coordOffset.latitude, longitude: coordOffset.longitude))
                let tapThresholdMeters = max(200.0, fingerWidthMeters)

                var closestIndex: Int? = nil
                var closestDistance = Double.greatestFiniteMagnitude

                // Busca la ruta no seleccionada más cercana al punto tocado
                for (index, route) in mapVM.routes.enumerated() {
                    guard index != mapVM.selectedRouteIndex else { continue }
                    let dist = minimumDistance(from: tapLocation, to: route.polyline)
                    if dist < tapThresholdMeters && dist < closestDistance {
                        closestDistance = dist
                        closestIndex = index
                    }
                }

                if let index = closestIndex {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mapVM.selectRoute(index: index)
                    }
                }
            }
        }
    }

    // Summary Overlay

    private var summaryOverlay: some View {
        VStack {
            TollSummaryBar(
                tollCount: feeVM.tollCharges.isEmpty ? mapVM.tollsOnRoute.count : feeVM.tollCharges.count,
                total: feeVM.totalPrice,
                isEstimated: feeVM.isEstimatedPrice,
                isLoadingPrices: feeVM.isLoadingPrices,
                vehicleType: vehicleType,
                fuelType: fuelType,
                hasAutopass: hasAutopass,
                originCoordinate: mapVM.originCoordinate,
                destinationCoordinate: mapVM.destinationCoordinate,
                fromAddress: from,
                toAddress: to,
                route: mapVM.route
            ) {
                showDetailsSheet = true
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding(.top, 8)

            Spacer()
        }
    }

    // Navigation Button Overlay

    private var navigationButtonOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                NavigationFloatingButton(
                    originCoordinate: mapVM.originCoordinate,
                    destinationCoordinate: mapVM.destinationCoordinate,
                    fromAddress: from,
                    toAddress: to
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // Helpers

    // Calcula la distancia mínima entre un punto y una polyline muestreando sus coordenadas
    private func minimumDistance(from location: CLLocation, to polyline: MKPolyline) -> Double {
        let count = polyline.pointCount
        guard count > 0 else { return .greatestFiniteMagnitude }

        var coords = Array(repeating: CLLocationCoordinate2D(), count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))

        return coords.min { a, b in
            location.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude)) <
            location.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }.map {
            location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
        } ?? .greatestFiniteMagnitude
    }

    private func routeTimeText(_ route: AppRoute) -> String {
        let total = Int(route.expectedTravelTime)
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)min" : "\(m) min"
    }

    // Devuelve la coordenada del punto medio de una polyline — donde colocar el callout
    private func polylineMidpoint(_ polyline: MKPolyline) -> CLLocationCoordinate2D? {
        let count = polyline.pointCount
        guard count > 0 else { return nil }
        var coords = Array(repeating: CLLocationCoordinate2D(), count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords[count / 2]
    }
}

// Triángulo apuntando hacia abajo — usado como "ganchito" del callout de ruta
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
