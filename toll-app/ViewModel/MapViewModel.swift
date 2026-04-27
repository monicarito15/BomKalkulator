
//  ViewModel: contiene la lógica de ubicación, rutas y tolls desde NVDB, hasResult(muestra la barra despues del calculo).


import SwiftUI
import MapKit
import CoreLocation

@MainActor
final class MapViewModel: ObservableObject {
    
    
    @Published var routes: [AppRoute] = []
    @Published var selectedRouteIndex: Int = 0
    @Published var toll: [Vegobjekt] = []
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var originCoordinate: CLLocationCoordinate2D?
    @Published var destinationCoordinate: CLLocationCoordinate2D?

    // Para la barrita + sheet
    @Published var hasResult: Bool = false
    @Published var totalPrice: Double = 0
    @Published var tollsOnRoute: [Vegobjekt] = []

    @Published var isLoadingRoute: Bool = false

    // Cache de peajes cercanos — se actualiza solo cuando cambia la ubicación
    @Published var nearbyTollsCache: [Vegobjekt] = []

    func updateNearbyTolls() {
        guard let userLocation else {
            nearbyTollsCache = []
            return
        }
        let allTolls = toll
        let loc = userLocation
        Task.detached(priority: .userInitiated) {
            let userCLLocation = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            let maxDistance: Double = 50_000
            let nearby = allTolls.filter { toll in
                guard let coordinates = toll.lokasjon?.coordinates else { return false }
                let tollLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
                return userCLLocation.distance(from: tollLocation) <= maxDistance
            }
            let sorted = nearby.sorted { t1, t2 in
                guard let d1 = t1.distanceInMeters(from: loc),
                      let d2 = t2.distanceInMeters(from: loc) else { return false }
                return d1 < d2
            }
            var deduped: [Vegobjekt] = []
            for toll in sorted {
                let name = toll.displayName
                let isVariant = deduped.contains { existing in
                    let en = existing.displayName
                    return name.hasPrefix(en) || en.hasPrefix(name)
                }
                if !isVariant { deduped.append(toll) }
            }
            let result = Array(deduped.prefix(10))
            await MainActor.run { self.nearbyTollsCache = result }
        }
    }

    var route: AppRoute? {
        guard selectedRouteIndex < routes.count else { return nil }
        return routes[selectedRouteIndex]
    }
    

    
    private let locationManager = LocationManager()
    
    func resetResult() {
        hasResult = false
        totalPrice = 0
        tollsOnRoute = []
        routes = []
        originCoordinate = nil
        destinationCoordinate = nil
        
    }
    
    func selectRoute(index: Int) {
        guard index < routes.count else { return }
        selectedRouteIndex = index  // UI responds instantly (route color changes)
        guard let route else { return }
        let capturedRoute = route
        let capturedTolls = toll
        Task.detached(priority: .userInitiated) {
            let result = MapViewModel.tollsNearRouteStatic(route: capturedRoute, tolls: capturedTolls)
            await MainActor.run { self.tollsOnRoute = result }
        }
    }

    func updateUserLocation() {
        userLocation = locationManager.userLocation
    }
    
    func fetchTolls() async {
        do {
            toll = try await TollService.shared.getTolls()
        } catch {
            #if DEBUG
            print("Error to fetch tolls: \(error)")
            #endif
        }
    }
    
  
    
    func getDirections(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async {
        let osrmRoutes = await OSRMService.shared.getRoutes(from: from, to: to)

        // Always also request MapKit routes for alternatives
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: .init(coordinate: from))
        req.destination = MKMapItem(placemark: .init(coordinate: to))
        req.transportType = .automobile
        req.requestsAlternateRoutes = true
        let mkRoutes = (try? await MKDirections(request: req).calculate())?.routes ?? []

        let mkAppRoutes = mkRoutes.map { r -> AppRoute in
            let hasFerry = r.steps.contains {
                let inst = $0.instructions.lowercased()
                return inst.contains("ferry") || inst.contains("ferje") || inst.contains("ferge")
            }
            return AppRoute(polyline: r.polyline, distance: r.distance,
                            expectedTravelTime: r.expectedTravelTime, name: r.name,
                            hasFerry: hasFerry)
        }

        var combined = osrmRoutes
        // Add MapKit routes that are significantly different (>300m distance difference)
        for mkRoute in mkAppRoutes {
            let isDuplicate = combined.contains { abs($0.distance - mkRoute.distance) < 300 }
            if !isDuplicate {
                combined.append(mkRoute)
            }
        }

        guard !combined.isEmpty else { return }

        selectedRouteIndex = 0
        routes = combined

        #if DEBUG
        print("Routes: \(routes.count) (OSRM: \(osrmRoutes.count), MapKit: \(mkAppRoutes.count))")
        for (i, r) in routes.enumerated() {
            print("  Route \(i): \(Int(r.distance/1000)) km — \(r.name)")
        }
        #endif
    }
    
    func geocode(from: CLLocationCoordinate2D, toAddress: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(toAddress) { placemarks, error in
            if let error = error {
                #if DEBUG
                print("Geocoder Error: \(error)")
                #endif
                return
            }
            if let destination = placemarks?.first?.location?.coordinate {
                Task {
                    await self.getDirections(from: from, to: destination)
                }
            } else {
                #if DEBUG
                print("No coordinate found for address: \(toAddress)")
                #endif
            }
        }
    }

    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        #if DEBUG
        print("Geocoding address: '\(address)'")
        #endif
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                #if DEBUG
                print("Geocoder Error for '\(address)': \(error.localizedDescription)")
                #endif
                completion(nil)
                return
            }
            
            if let coordinate = placemarks?.first?.location?.coordinate {
                #if DEBUG
                print("Geocoded '\(address)' → \(coordinate.latitude), \(coordinate.longitude)")
                #endif
                completion(coordinate)
            } else {
                #if DEBUG
                print("No coordinate found for address: '\(address)'")
                #endif
                completion(nil)
            }
        }
    }
    
    
    func getDirectionsFromAddresses(
        fromAddress: String,
        toAddress: String,
        fromCoordinate: CLLocationCoordinate2D? = nil,
        toCoordinate: CLLocationCoordinate2D? = nil
    ) async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }
        
        let fromTrim = fromAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let toTrim = toAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !toTrim.isEmpty || toCoordinate != nil else {
            #if DEBUG
            print("Missing 'to' address")
            #endif
            return
        }
        
        
        let destination: CLLocationCoordinate2D
        if let toCoordinate {
            destination = toCoordinate
        } else {
            guard let geocoded = await geocodeAddressAsync(toTrim) else {
                #if DEBUG
                print("No coordinate found for TO: \(toTrim)")
                #endif
                return
            }
            destination = geocoded
        }
        
        #if DEBUG
        print("Destination: \(destination.latitude), \(destination.longitude)")
        #endif
        destinationCoordinate = destination
        
      
        let origin: CLLocationCoordinate2D
        if let fromCoordinate {
            origin = fromCoordinate
        } else if fromTrim.isEmpty {
            #if DEBUG
            print("FROM is empty, using user location...")
            #endif
            updateUserLocation()
            guard let userLoc = userLocation else {
                #if DEBUG
                print("No user location available yet")
                #endif
                return
            }
            origin = userLoc
        } else {
            guard let geocoded = await geocodeAddressAsync(fromTrim) else {
                #if DEBUG
                print("No coordinate found for FROM: \(fromTrim)")
                #endif
                return
            }
            origin = geocoded
        }
        
        #if DEBUG
        print("Origin: \(origin.latitude), \(origin.longitude)")
        #endif
        originCoordinate = origin
        
        await getDirections(from: origin, to: destination)
    }
    
    private func geocodeAddressAsync(_ address: String) async -> CLLocationCoordinate2D? {
        #if DEBUG
        print("Geocoding address: '\(address)'")
        #endif
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            #if DEBUG
            print("Geocoder Error for '\(address)': \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    func buildResultIfPossible(vehicle: VehicleType, fuel: FuelType, date: Date) {
        guard let route else { return }
        guard !toll.isEmpty else { return }

        let capturedRoute = route
        let capturedTolls = toll
        Task.detached(priority: .userInitiated) {
            let result = MapViewModel.tollsNearRouteStatic(route: capturedRoute, tolls: capturedTolls)
            await MainActor.run { self.tollsOnRoute = result }
        }
        totalPrice = 0
        hasResult = true
    }


    private nonisolated static func tollsNearRouteStatic(route: AppRoute, tolls: [Vegobjekt], maxDistanceMeters: Double = 50) -> [Vegobjekt] {
        let polyline = route.polyline
        let count = polyline.pointCount
        guard count > 0 else { return [] }

        var coords = Array(repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0), count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))

        var tollsWithPosition: [(toll: Vegobjekt, routeIndex: Int, distance: Double)] = []

        for toll in tolls {
            guard let c = toll.lokasjon?.coordinates else { continue }

            var closestIndex = -1
            var closestDistance = Double.greatestFiniteMagnitude

            for i in 0..<(count - 1) {
                let d = distanceFromPoint(c, toSegmentFrom: coords[i], to: coords[i + 1])
                if d < closestDistance {
                    closestDistance = d
                    closestIndex = i
                }
            }

            if closestDistance <= maxDistanceMeters {
                if let requiredBearing = directionalBearing(for: toll) {
                    let a = coords[max(0, closestIndex)]
                    let b = coords[min(count - 1, closestIndex + 1)]
                    let routeBearing = bearing(from: a, to: b)
                    if angleDifference(routeBearing, requiredBearing) > 90 { continue }
                }
                tollsWithPosition.append((toll: toll, routeIndex: closestIndex, distance: closestDistance))
            }
        }

        
        // When one name is a prefix of another and they're close on the route, keep only the closest.
        let sorted = tollsWithPosition.sorted { $0.distance < $1.distance }
        var deduped: [(toll: Vegobjekt, routeIndex: Int, distance: Double)] = []
        for item in sorted {
            let name = item.toll.displayName
            let dominated = deduped.contains { existing in
                let en = existing.toll.displayName
                let sameGroup = name.hasPrefix(en) || en.hasPrefix(name)
                let closeOnRoute = abs(existing.routeIndex - item.routeIndex) < 100
                return sameGroup && closeOnRoute
            }
            if !dominated { deduped.append(item) }
        }

        return deduped
            .sorted { $0.routeIndex < $1.routeIndex }
            .map { $0.toll }
    }

    // Returns the cardinal bearing a directional toll expects, nil if non-directional
    private nonisolated static func directionalBearing(for toll: Vegobjekt) -> Double? {
        let name = toll.displayName.lowercased()
        if name.contains("nordgående") { return 0 }
        if name.contains("sørgående")  { return 180 }
        if name.contains("østgående")  { return 90 }
        if name.contains("vestgående") { return 270 }
        return nil
    }

    // Compass bearing in degrees (0=N, 90=E, 180=S, 270=W)
    private nonisolated static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude  * .pi / 180
        let lat2 = b.latitude  * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // Smallest angular difference between two bearings (0–180)
    private nonisolated static func angleDifference(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    // Minimum distance from point P to segment A→B using projection
    private nonisolated static func distanceFromPoint(
        _ p: CLLocationCoordinate2D,
        toSegmentFrom a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D
    ) -> Double {
        let ax = a.longitude, ay = a.latitude
        let bx = b.longitude, by = b.latitude
        let px = p.longitude, py = p.latitude

        let dx = bx - ax, dy = by - ay
        let lenSq = dx * dx + dy * dy

        let closest: CLLocationCoordinate2D
        if lenSq == 0 {
            closest = a
        } else {
            let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq))
            closest = CLLocationCoordinate2D(latitude: ay + t * dy, longitude: ax + t * dx)
        }

        return CLLocation(latitude: p.latitude, longitude: p.longitude)
            .distance(from: CLLocation(latitude: closest.latitude, longitude: closest.longitude))
    }
        
}
