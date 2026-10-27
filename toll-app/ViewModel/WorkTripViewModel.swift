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
    @Published var resumeCountdown: Int = 0
    @Published var currentAddress: String = ""

    static let countdownDuration = 10

    private var timer: Timer?
    private var countdownTask: Task<Void, Never>?
    private var tripStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPausedSeconds: Int = 0
    private var lastLocation: CLLocation?
    private var lastGeocodedAt: Date = .distantPast
    private var locationTask: Task<Void, Never>?
    private var speedAboveThresholdSeconds: Int = 0

    private static let autoResumeSpeedThreshold: Double = 2.78  // 10 km/h in m/s
    private static let autoResumeRequiredSeconds: Int = 10

    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    #if DEBUG
    func debugTriggerAutoResume() {
        triggerAutoResumeCountdown()
    }
    #endif

    var autoResumeEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoResume") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "autoResume")
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
        speedAboveThresholdSeconds = 0
        startTimer()
        startLocationTracking(monitoringForResume: false)
    }

    func endTrip(context: ModelContext, driverName: String, company: String) {
        stopTimer()
        stopLocationTracking()
        cancelCountdown()

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
        cancelCountdown()
        pauseStartTime = Date()
        tripState = .autoPaused
        speedAboveThresholdSeconds = 0
        startLocationTracking(monitoringForResume: true)
    }

    func resumeTrip() {
        if let pause = pauseStartTime {
            totalPausedSeconds += Int(Date().timeIntervalSince(pause))
        }
        pauseStartTime = nil
        speedAboveThresholdSeconds = 0
        showResumeNotification = false
        resumeCountdown = 0
        tripState = .active
        startTimer()
        startLocationTracking(monitoringForResume: false)
    }

    func cancelAutoResume() {
        cancelCountdown()
        showResumeNotification = false
        resumeCountdown = 0
        speedAboveThresholdSeconds = 0
        stopTimer()
        if pauseStartTime == nil { pauseStartTime = Date() }
        tripState = .autoPaused
        startLocationTracking(monitoringForResume: true)
    }

    private func triggerAutoResumeCountdown() {
        guard autoResumeEnabled else { return }
        showResumeNotification = true
        resumeCountdown = Self.countdownDuration
        countdownTask = Task {
            do {
                while resumeCountdown > 0 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    resumeCountdown -= 1
                }
                if !Task.isCancelled {
                    resumeTrip()
                }
            } catch {
                // task cancelled
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
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

    private func startLocationTracking(monitoringForResume: Bool) {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let updates = CLLocationUpdate.liveUpdates()
                for try await update in updates {
                    guard !Task.isCancelled else { return }
                    guard let location = update.location else { continue }

                    if monitoringForResume {
                        guard !self.showResumeNotification else { continue }
                        let speed = location.speed
                        if speed > Self.autoResumeSpeedThreshold {
                            self.speedAboveThresholdSeconds += 1
                            if self.speedAboveThresholdSeconds >= Self.autoResumeRequiredSeconds
                                && self.tripState == .autoPaused {
                                self.triggerAutoResumeCountdown()
                                return
                            }
                        } else {
                            self.speedAboveThresholdSeconds = 0
                        }
                    } else {
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
        speedAboveThresholdSeconds = 0
        showResumeNotification = false
        resumeCountdown = 0
    }
}
