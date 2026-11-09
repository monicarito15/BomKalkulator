import SwiftUI
import SwiftData
import CoreLocation
import UserNotifications

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
    @Published var passages: [TollPassage] = []

    static let countdownDuration = 10

    private var timer: Timer?
    private var countdownTask: Task<Void, Never>?
    private var tripStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPausedTime: TimeInterval = 0
    private var lastLocation: CLLocation?
    private var lastGeocodedAt: Date = .distantPast
    private var locationTask: Task<Void, Never>?
    private var speedAboveThresholdSeconds: Int = 0
    private var capturedStartCity: String = ""
    private var capturedEndCity: String = ""
    private var stationaryStartTime: Date? = nil
    private var loadedTolls: [Vegobjekt] = []
    private var recentlyPassed: [Int: Date] = [:]

    private static let autoResumeSpeedThreshold: Double = 2.78  // 10 km/h in m/s
    private static let tollPassageRadius: Double = 50.0           // meters (matches route detection)
    private static let tollPassageCooldown: TimeInterval = 60.0  // seconds per station
    private static let autoResumeRequiredSeconds: Int = 10
    private static let autoPauseSpeedThreshold: Double = 1.39   // 5 km/h in m/s
    private static let autoPauseRequiredSeconds: Double = 600   // 10 minutes

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
        totalPausedTime = 0
        elapsedSeconds = 0
        distanceKm = 0
        tollCount = 0
        totalTollCost = 0
        lastLocation = nil
        speedAboveThresholdSeconds = 0
        capturedStartCity = ""
        capturedEndCity = ""
        stationaryStartTime = nil
        startTimer()
        startLocationTracking(monitoringForResume: false)
        Task { await self.loadTolls() }
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
        trip.startCity = capturedStartCity
        trip.endCity = capturedEndCity.isEmpty ? capturedStartCity : capturedEndCity
        trip.passages = passages
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
            totalPausedTime += Date().timeIntervalSince(pause)
        }
        pauseStartTime = nil
        speedAboveThresholdSeconds = 0
        stationaryStartTime = nil
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
        stopTimer()
        stopLocationTracking()
        if pauseStartTime == nil { pauseStartTime = Date() }
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
                    sendNotification(
                        title: LanguageManager.shared.t(nb: "Kjøretur gjenopptatt", en: "Trip resumed"),
                        body: LanguageManager.shared.t(nb: "Bevegelse oppdaget — turen fortsetter.", en: "Movement detected — trip is continuing.")
                    )
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
                let raw = Date().timeIntervalSince(start)
                self.elapsedSeconds = max(0, Int(raw - self.totalPausedTime))
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
                        self.checkTollPassage(at: location)

                        // Auto-pause after 10 min stationary
                        let speed = location.speed
                        if speed >= 0 && speed < Self.autoPauseSpeedThreshold {
                            if self.stationaryStartTime == nil {
                                self.stationaryStartTime = Date()
                            } else if let since = self.stationaryStartTime,
                                      Date().timeIntervalSince(since) >= Self.autoPauseRequiredSeconds {
                                self.stationaryStartTime = nil
                                self.sendNotification(
                                    title: LanguageManager.shared.t(nb: "Kjøretur pauset", en: "Trip paused"),
                                    body: LanguageManager.shared.t(nb: "Ingen bevegelse på 10 min. Åpne appen for å gjenoppta.", en: "No movement for 10 min. Open the app to resume.")
                                )
                                self.pauseTrip()
                                return
                            }
                        } else {
                            self.stationaryStartTime = nil
                        }

                        if self.capturedStartCity.isEmpty {
                            self.lastGeocodedAt = Date()
                            await self.reverseGeocode(location)
                            self.capturedStartCity = self.capturedEndCity
                        } else if Date().timeIntervalSince(self.lastGeocodedAt) > 30 {
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

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func reverseGeocode(_ location: CLLocation) async {
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let parts = [placemark.thoroughfare, placemark.locality].compactMap { $0 }
                self.currentAddress = parts.joined(separator: ", ")
                self.capturedEndCity = placemark.locality ?? placemark.administrativeArea ?? ""
            }
        } catch {
            #if DEBUG
            print("WorkTripViewModel geocode error: \(error)")
            #endif
        }
    }

    private func loadTolls() async {
        do {
            loadedTolls = try await TollService.shared.getTolls()
        } catch {
            #if DEBUG
            print("WorkTripViewModel: failed to load tolls: \(error)")
            #endif
        }
    }

    private func checkTollPassage(at location: CLLocation) {
        guard !loadedTolls.isEmpty else { return }
        let coord = location.coordinate
        let now = Date()
        let userCourse = location.course  // -1 if unavailable (stationary / no fix)
        let vehicle = VehicleType(rawValue: UserDefaults.standard.string(forKey: "defaultVehicle") ?? "") ?? .car
        let fuel = FuelType(rawValue: UserDefaults.standard.string(forKey: "defaultFuel") ?? "") ?? .gas

        for toll in loadedTolls {
            guard let dist = toll.distanceInMeters(from: coord),
                  dist <= Self.tollPassageRadius else { continue }

            if let lastPassed = recentlyPassed[toll.id],
               now.timeIntervalSince(lastPassed) < Self.tollPassageCooldown { continue }

            // Skip if toll is directional and user is heading the wrong way
            if userCourse >= 0, let required = toll.requiredBearing {
                if angleDifference(userCourse, required) > 90 { continue }
            }

            guard let price = toll.price(vehicle: vehicle, fuel: fuel, date: now) else { continue }

            let passage = TollPassage(stationName: toll.stationName, price: price, passedAt: now)
            passages.append(passage)
            tollCount += 1
            totalTollCost += price
            recentlyPassed[toll.id] = now
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
        totalPausedTime = 0
        currentAddress = ""
        capturedStartCity = ""
        capturedEndCity = ""
        stationaryStartTime = nil
        speedAboveThresholdSeconds = 0
        showResumeNotification = false
        resumeCountdown = 0
        passages = []
        loadedTolls = []
        recentlyPassed = [:]
    }
}
