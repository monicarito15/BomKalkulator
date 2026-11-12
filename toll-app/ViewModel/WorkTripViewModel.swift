import ActivityKit
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
    @Published var hasInterruptedTrip: Bool = false
    @Published var selectedVehicleType: VehicleType = .car
    @Published var selectedFuelType: FuelType = .gas

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
    private var tollCoordinates: [Int: CLLocationCoordinate2D] = [:]
    private var recentlyPassed: [Int: Date] = [:]
    private var backgroundSession: CLBackgroundActivitySession?
    private var liveActivity: Activity<WorkTripActivityAttributes>?
    private var lastPersistAt: Date = .distantPast

    private static let autoResumeSpeedThreshold: Double = 2.78  // 10 km/h in m/s
    private static let tollPassageRadius: Double = 50.0           // meters
    private static let tollPassageCooldown: TimeInterval = 60.0  // seconds per station
    private static let autoResumeRequiredSeconds: Int = 10
    private static let autoPauseSpeedThreshold: Double = 1.39   // 5 km/h in m/s
    private static let autoPauseRequiredSeconds: Double = 600   // 10 minutes
    private static let persistedTripKey = "activeWorkTrip"

    // MARK: - Crash recovery state

    private struct PersistedTripState: Codable {
        var startTime: Date
        var totalPausedTime: TimeInterval
        var lastElapsedSeconds: Int
        var distanceKm: Double
        var tollCount: Int
        var totalTollCost: Double
        var passages: [TollPassage]
        var startCity: String
        var endCity: String
        var vehicleType: String
        var fuelType: String
    }

    init() {
        selectedVehicleType = VehicleType(rawValue: UserDefaults.standard.string(forKey: "defaultVehicle") ?? "") ?? .car
        selectedFuelType = FuelType(rawValue: UserDefaults.standard.string(forKey: "defaultFuel") ?? "") ?? .gas
        checkForInterruptedTrip()
        endOrphanedLiveActivities()
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            backgroundSession?.invalidate()
            locationTask?.cancel()
        }
    }

    deinit {
        backgroundSession?.invalidate()
        locationTask?.cancel()
    }

    // MARK: - Crash recovery methods

    private func checkForInterruptedTrip() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistedTripKey),
              let state = try? JSONDecoder().decode(PersistedTripState.self, from: data),
              Date().timeIntervalSince(state.startTime) < 86400 else {
            UserDefaults.standard.removeObject(forKey: Self.persistedTripKey)
            return
        }
        hasInterruptedTrip = true
    }

    private func persistState() {
        guard let start = tripStartTime else { return }
        let state = PersistedTripState(
            startTime: start,
            totalPausedTime: totalPausedTime,
            lastElapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            tollCount: tollCount,
            totalTollCost: totalTollCost,
            passages: passages,
            startCity: capturedStartCity,
            endCity: capturedEndCity,
            vehicleType: selectedVehicleType.rawValue,
            fuelType: selectedFuelType.rawValue
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.persistedTripKey)
        }
        lastPersistAt = Date()
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: Self.persistedTripKey)
    }

    func resumeInterruptedTrip() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistedTripKey),
              let state = try? JSONDecoder().decode(PersistedTripState.self, from: data) else {
            hasInterruptedTrip = false
            return
        }
        hasInterruptedTrip = false
        tripStartTime = state.startTime
        distanceKm = state.distanceKm
        tollCount = state.tollCount
        totalTollCost = state.totalTollCost
        passages = state.passages
        capturedStartCity = state.startCity
        capturedEndCity = state.endCity
        selectedVehicleType = VehicleType(rawValue: state.vehicleType) ?? .car
        selectedFuelType = FuelType(rawValue: state.fuelType) ?? .gas
        elapsedSeconds = state.lastElapsedSeconds
        // Adjust totalPausedTime so elapsed stays at lastElapsedSeconds right now
        totalPausedTime = Date().timeIntervalSince(state.startTime) - Double(state.lastElapsedSeconds)
        tripState = .active
        backgroundSession = CLBackgroundActivitySession()
        startTimer()
        startLocationTracking(monitoringForResume: false)
        Task { await self.loadTolls() }
        let name = UserDefaults.standard.string(forKey: "driverName") ?? ""
        startLiveActivity(driverName: name)
    }

    func discardInterruptedTrip() {
        clearPersistedState()
        hasInterruptedTrip = false
    }

    // MARK: - Trip lifecycle

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
        backgroundSession = CLBackgroundActivitySession()
        startTimer()
        startLocationTracking(monitoringForResume: false)
        Task { await self.loadTolls() }
        let name = UserDefaults.standard.string(forKey: "driverName") ?? ""
        startLiveActivity(driverName: name)
        persistState()
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

        endLiveActivity()
        clearPersistedState()
        resetState()
    }

    func pauseTrip() {
        stopTimer()
        cancelCountdown()
        pauseStartTime = Date()
        tripState = .autoPaused
        speedAboveThresholdSeconds = 0
        startLocationTracking(monitoringForResume: true)
        updateLiveActivity(paused: true)
        persistState()
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
        updateLiveActivity(paused: false)
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

                if self.tripState == .active,
                   let since = self.stationaryStartTime,
                   Date().timeIntervalSince(since) >= Self.autoPauseRequiredSeconds {
                    self.stationaryStartTime = nil
                    self.sendNotification(
                        title: LanguageManager.shared.t(nb: "Kjøretur pauset", en: "Trip paused"),
                        body: LanguageManager.shared.t(nb: "Ingen bevegelse på 10 min. Åpne appen for å gjenoppta.", en: "No movement for 10 min. Open the app to resume."),
                        userInfo: ["action": "openWorkTrip"]
                    )
                    self.pauseTrip()
                }

                // Persist state every 60 seconds while active
                if self.tripState == .active,
                   Date().timeIntervalSince(self.lastPersistAt) >= 60 {
                    self.persistState()
                }
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

                        // Track stationary time — trigger handled by the 1s timer
                        // speed < 0 means GPS couldn't compute it (unknown) — don't reset
                        let speed = location.speed
                        let clearlyMoving = speed >= 0 && speed >= Self.autoPauseSpeedThreshold
                        if clearlyMoving {
                            self.stationaryStartTime = nil
                        } else if self.stationaryStartTime == nil {
                            self.stationaryStartTime = Date()
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

    private func sendNotification(title: String, body: String, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
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
            let tolls = try await TollService.shared.getTolls()
            var coords: [Int: CLLocationCoordinate2D] = [:]
            for toll in tolls {
                if let c = toll.lokasjon?.coordinates {
                    coords[toll.id] = c
                }
            }
            tollCoordinates = coords
            loadedTolls = tolls
        } catch {
            #if DEBUG
            print("WorkTripViewModel: failed to load tolls: \(error)")
            #endif
        }
    }

    private func checkTollPassage(at location: CLLocation) {
        guard !loadedTolls.isEmpty else { return }
        let now = Date()
        let userCourse = location.course  // -1 if unavailable (stationary / no fix)

        for toll in loadedTolls {
            guard let tollCoord = tollCoordinates[toll.id] else { continue }

            let tollLoc = CLLocation(latitude: tollCoord.latitude, longitude: tollCoord.longitude)
            guard location.distance(from: tollLoc) <= Self.tollPassageRadius else { continue }

            if let lastPassed = recentlyPassed[toll.id],
               now.timeIntervalSince(lastPassed) < Self.tollPassageCooldown { continue }

            // Skip if toll is directional and user is heading the wrong way
            if userCourse >= 0, let required = toll.requiredBearing {
                if angleDifference(userCourse, required) > 90 { continue }
            }

            guard let price = toll.price(vehicle: selectedVehicleType, fuel: selectedFuelType, date: now) else { continue }

            let passage = TollPassage(stationName: toll.stationName, price: price, passedAt: now)
            passages.append(passage)
            tollCount += 1
            totalTollCost += price
            recentlyPassed[toll.id] = now
            updateLiveActivity(paused: false)
            persistState()
        }
    }

    private func endOrphanedLiveActivities() {
        Task {
            for activity in Activity<WorkTripActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func startLiveActivity(driverName: String) {
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("[LiveActivity] areActivitiesEnabled: \(enabled)")
        guard enabled else {
            print("[LiveActivity] aborted — activities not enabled")
            return
        }
        let state = WorkTripActivityAttributes.ContentState(
            tripState: "active",
            timerStart: Date(),
            elapsedSeconds: 0,
            distanceKm: 0,
            tollCount: 0,
            totalTollCost: 0
        )
        let attributes = WorkTripActivityAttributes(driverName: driverName)
        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("[LiveActivity] started — id: \(liveActivity?.id ?? "nil"), state: \(String(describing: liveActivity?.activityState))")
        } catch {
            print("[LiveActivity] ERROR: \(error)")
        }
    }

    private func updateLiveActivity(paused: Bool) {
        guard let activity = liveActivity else { return }
        let timerStart: Date
        if paused {
            // Frozen date — doesn't matter, we show static elapsed text
            timerStart = Date()
        } else {
            // Set timerStart so that "now - timerStart == elapsedSeconds"
            timerStart = Date().addingTimeInterval(-Double(elapsedSeconds))
        }
        let state = WorkTripActivityAttributes.ContentState(
            tripState: paused ? "paused" : "active",
            timerStart: timerStart,
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            tollCount: tollCount,
            totalTollCost: totalTollCost
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = WorkTripActivityAttributes.ContentState(
            tripState: "paused",
            timerStart: Date(),
            elapsedSeconds: elapsedSeconds,
            distanceKm: distanceKm,
            tollCount: tollCount,
            totalTollCost: totalTollCost
        )
        Task {
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        liveActivity = nil
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
        tollCoordinates = [:]
        recentlyPassed = [:]
        backgroundSession?.invalidate()
        backgroundSession = nil
        liveActivity = nil
    }
}
