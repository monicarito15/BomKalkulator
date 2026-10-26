import SwiftUI
import SwiftData
import CoreLocation

enum WorkTripState: Equatable {
    case idle
    case active
    case autoPaused
}

@MainActor
final class WorkTripViewModel: ObservableObject {
    @Published var tripState: WorkTripState = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var distanceKm: Double = 0.0
    @Published var tollCount: Int = 0
    @Published var totalTollCost: Double = 0.0
    @Published var showResumeNotification: Bool = false
    @Published var currentAddress: String = ""

    private var timer: Timer?
    private var tripStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPausedSeconds: Int = 0
    private var lastLocation: CLLocation?
    private var lastGeocodedAt: Date = .distantPast
    private var locationTask: Task<Void, Never>?

    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        if h > 0 { return "\(h) h \(m) min" }
        return "\(m) min"
    }

    func startTrip() {
        tripState = .active
        tripStartTime = Date()
        totalPausedSeconds = 0
        elapsedSeconds = 0
        distanceKm = 0
        tollCount = 0
        totalTollCost = 0
        lastLocation = nil
        startTimer()
        startLocationTracking()
    }

    func endTrip(context: ModelContext, driverName: String, company: String) {
        stopTimer()
        stopLocationTracking()

        let trip = WorkTrip(driverName: driverName, company: company)
        trip.startTime = tripStartTime ?? Date()
        trip.endTime = Date()
        trip.distanceKm = distanceKm
        trip.totalTollCost = totalTollCost
        trip.status = .completed
        context.insert(trip)
        try? context.save()

        resetState()
    }

    func pauseTrip() {
        stopTimer()
        stopLocationTracking()
        pauseStartTime = Date()
        tripState = .autoPaused
    }

    func resumeTrip(isAuto: Bool = false) {
        if let pause = pauseStartTime {
            totalPausedSeconds += Int(Date().timeIntervalSince(pause))
        }
        pauseStartTime = nil
        tripState = .active
        startTimer()
        startLocationTracking()
        if isAuto {
            showResumeNotification = true
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                showResumeNotification = false
            }
        }
    }

    func cancelAutoResume() {
        showResumeNotification = false
        pauseTrip()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.tripStartTime else { return }
                let raw = Int(Date().timeIntervalSince(start))
                self.elapsedSeconds = max(0, raw - self.totalPausedSeconds)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startLocationTracking() {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard !Task.isCancelled else { return }
                    guard let location = update.location else { continue }

                    if let last = self.lastLocation {
                        let delta = location.distance(from: last) / 1000.0
                        if delta > 0.01 {
                            self.distanceKm += delta
                        }
                    }
                    self.lastLocation = location

                    if Date().timeIntervalSince(self.lastGeocodedAt) > 30 {
                        self.lastGeocodedAt = Date()
                        await self.reverseGeocode(location)
                    }
                }
            } catch {
                #if DEBUG
                print("WorkTripViewModel location error: \(error)")
                #endif
            }
        }
    }

    private func stopLocationTracking() {
        locationTask?.cancel()
        locationTask = nil
    }

    private func reverseGeocode(_ location: CLLocation) async {
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let parts = [placemark.thoroughfare, placemark.locality].compactMap { $0 }
                self.currentAddress = parts.joined(separator: ", ")
            }
        } catch {
            #if DEBUG
            print("WorkTripViewModel geocode error: \(error)")
            #endif
        }
    }

    private func resetState() {
        tripState = .idle
        elapsedSeconds = 0
        distanceKm = 0
        tollCount = 0
        totalTollCost = 0
        lastLocation = nil
        tripStartTime = nil
        currentAddress = ""
    }
}
