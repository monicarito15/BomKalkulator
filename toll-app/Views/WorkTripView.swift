import SwiftUI
import SwiftData

struct WorkTripView: View {
    @StateObject private var vm = WorkTripViewModel()
    @ObservedObject private var lang = LanguageManager.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("driverName") private var driverName: String = ""
    @AppStorage("companyName") private var companyName: String = ""
    @State private var showEndTripAlert = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    switch vm.tripState {
                    case .idle:
                        idleView
                    case .active:
                        activeView
                    case .autoPaused:
                        pausedView
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: vm.tripState)

                if vm.showResumeNotification {
                    resumeNotificationBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle(lang.t(nb: "Kjøretur", en: "Work Trip"))
            .navigationBarTitleDisplayMode(.large)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.showResumeNotification)
            .alert(lang.t(nb: "Avslutt kjøreturen?", en: "Stop this trip?"), isPresented: $showEndTripAlert) {
                Button(lang.t(nb: "Ja, avslutt og lagre", en: "Yes, stop and save"), role: .destructive) {
                    vm.endTrip(context: modelContext, driverName: driverName, company: companyName)
                }
                Button(lang.t(nb: "Fortsett", en: "Keep going"), role: .cancel) {}
            } message: {
                Text(lang.t(nb: "Turen lagres og kan ikke fortsettes.", en: "Your trip will be saved and you won't be able to continue it."))
            }
        }
    }

    private var tripHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.headline)
                    .fontWeight(.bold)

                if !driverName.isEmpty || !companyName.isEmpty {
                    let subtitle = [driverName, companyName]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if vm.tripState == .active {
                PulsingDot()
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var idleView: some View {
        VStack(spacing: 0) {
            tripHeader.padding(.top, 8)

            if vm.hasInterruptedTrip {
                recoveryBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    vm.requestNotificationPermission()
                    vm.startTrip()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 140, height: 140)
                            .shadow(color: Color.green.opacity(0.35), radius: 20, x: 0, y: 8)
                        Text("START")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(lang.t(nb: "Start kjøretur", en: "Start work trip"))
                    .font(.title3.weight(.semibold))

                Text(lang.t(nb: "Vi sporer distanse, tid og bompasseringer.", en: "We'll track distance, time and toll passages."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                vehiclePickerSection
                    .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var recoveryBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(lang.t(nb: "Avbrutt kjøretur funnet", en: "Interrupted trip found"))
                    .font(.subheadline.weight(.semibold))
            }
            Text(lang.t(nb: "Forrige tur ble avbrutt. Vil du fortsette der du slapp?", en: "Your last trip was interrupted. Continue where you left off?"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    vm.resumeInterruptedTrip()
                } label: {
                    Text(lang.t(nb: "Fortsett", en: "Continue"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    withAnimation {
                        vm.discardInterruptedTrip()
                    }
                } label: {
                    Text(lang.t(nb: "Forkast", en: "Discard"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1.5))
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    private var vehiclePickerSection: some View {
        VStack(spacing: 10) {
            Picker("", selection: $vm.selectedVehicleType) {
                Text(lang.t(nb: "Bil", en: "Car")).tag(VehicleType.car)
                Text(lang.t(nb: "Motorsykkel", en: "Motorcycle")).tag(VehicleType.motorcycle)
            }
            .pickerStyle(.segmented)

            Picker("", selection: $vm.selectedFuelType) {
                Text("Elbil").tag(FuelType.electric)
                Text("Diesel").tag(FuelType.diesel)
                Text(lang.t(nb: "Bensin", en: "Petrol")).tag(FuelType.gas)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 40)
    }

    private var activeView: some View {
        ScrollView {
            VStack(spacing: 16) {
                tripHeader.padding(.top, 8)

                HStack(spacing: 12) {
                    statCard(
                        label: lang.t(nb: "DISTANSE", en: "DISTANCE"),
                        value: String(format: "%.2f", vm.distanceKm),
                        unit: "km"
                    )
                    statCard(
                        label: lang.t(nb: "TID", en: "TIME"),
                        value: vm.formattedElapsed,
                        unit: nil
                    )
                }
                .padding(.horizontal, 16)

                tollCard
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    Button {
                        showEndTripAlert = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 130, height: 130)
                                .shadow(color: Color.red.opacity(0.35), radius: 20, x: 0, y: 8)
                            VStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("STOP")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    Text(lang.t(nb: "Kjøretur pågår", en: "Work trip in progress"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !vm.showResumeNotification {
                        Button {
                            vm.pauseTrip()
                        } label: {
                            Label(lang.t(nb: "Sett på pause", en: "Set on pause"), systemImage: "pause.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }

                    #if DEBUG
                    Button("⚙ Test resume banner") {
                        vm.debugTriggerAutoResume()
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    #endif
                }
                .padding(.vertical, 8)

                if !vm.currentAddress.isEmpty && !vm.showResumeNotification {
                    currentPositionCard
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 20)
            }
            .padding(.bottom, 16)
        }
    }

    private var pausedView: some View {
        ScrollView {
            VStack(spacing: 16) {
                tripHeader.padding(.top, 8)

                pauseCard
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.25))
                            .frame(width: 130, height: 130)
                        VStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("STOP")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Text(lang.t(nb: "Kjøretur pågår", en: "Work trip in progress"))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)

                Spacer(minLength: 20)
            }
        }
    }

    private var pauseCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange)
                        .frame(width: 40, height: 40)
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t(nb: "Tur satt på pause", en: "Trip auto-paused"))
                        .font(.subheadline.weight(.semibold))
                    Text(lang.t(nb: "Du har stoppet", en: "You are stopped"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    vm.resumeTrip()
                } label: {
                    Text(lang.t(nb: "Fortsett", en: "Continue"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    showEndTripAlert = true
                } label: {
                    Text(lang.t(nb: "Avslutt tur", en: "End trip"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 1.5))
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    private var tollCard: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t(nb: "BOMSTASJONER", en: "TOLL STATIONS"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("\(vm.tollCount) \(lang.t(nb: vm.tollCount == 1 ? "passering" : "passeringer", en: vm.tollCount == 1 ? "passage" : "passages"))")
                    .font(.title3.weight(.bold))
            }
            Spacer()
            Text(String(format: "%.2f kr", vm.totalTollCost))
                .font(.title3.weight(.bold))
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }

    private var currentPositionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t(nb: "NÅVÆRENDE POSISJON", en: "CURRENT POSITION"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(vm.currentAddress)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }

    private var resumeNotificationBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.t(nb: "Det ser ut som du beveger deg", en: "Looks like you're moving"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(format: lang.t(nb: "Turen gjenopptas om %ds...", en: "Your trip resumes in %ds..."), vm.resumeCountdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CountdownCircle(
                    countdown: vm.resumeCountdown,
                    total: WorkTripViewModel.countdownDuration
                )
            }

            Button {
                withAnimation {
                    vm.cancelAutoResume()
                }
            } label: {
                Text(lang.t(nb: "Ikke klar? Hold turen på pause.", en: "Not ready yet? Keep it paused."))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .padding(.horizontal, 16)
    }

    private func statCard(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
}

struct CountdownCircle: View {
    let countdown: Int
    let total: Int

    private var progress: CGFloat {
        total > 0 ? CGFloat(countdown) / CGFloat(total) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 3)
                .frame(width: 44, height: 44)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 44, height: 44)
                .animation(.linear(duration: 1), value: progress)

            Text("\(countdown)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 18, height: 18)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)

            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    WorkTripView()
        .modelContainer(for: WorkTrip.self, inMemory: true)
}
