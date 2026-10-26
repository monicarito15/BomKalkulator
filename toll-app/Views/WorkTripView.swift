import SwiftUI
import SwiftData

struct WorkTripView: View {
    @StateObject private var vm = WorkTripViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("driverName") private var driverName: String = ""
    @AppStorage("companyName") private var companyName: String = ""

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
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
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Work Trip")
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.25), value: vm.showResumeNotification)
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

            Spacer()

            VStack(spacing: 12) {
                Button {
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

                Text("Start work trip")
                    .font(.title3.weight(.semibold))

                Text("We'll track distance, time and toll passages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var activeView: some View {
        ScrollView {
            VStack(spacing: 16) {
                tripHeader.padding(.top, 8)

                HStack(spacing: 12) {
                    statCard(
                        label: "DISTANCE",
                        value: String(format: "%.1f", vm.distanceKm),
                        unit: "km"
                    )
                    statCard(
                        label: "TIME",
                        value: vm.formattedElapsed,
                        unit: nil
                    )
                }
                .padding(.horizontal, 16)

                tollCard
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    Button {
                        vm.endTrip(context: modelContext, driverName: driverName, company: companyName)
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

                    Text("Work trip in progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Set on pause") {
                        vm.pauseTrip()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
                .padding(.vertical, 8)

                if !vm.currentAddress.isEmpty {
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

                    Text("Work trip in progress")
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
                    Text("Trip auto-paused")
                        .font(.subheadline.weight(.semibold))
                    Text("You are stopped")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    vm.resumeTrip()
                } label: {
                    Text("Continue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    vm.endTrip(context: modelContext, driverName: driverName, company: companyName)
                } label: {
                    Text("End trip")
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
                Text("TOLL STATIONS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("\(vm.tollCount) passage\(vm.tollCount == 1 ? "" : "s")")
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
                Text("CURRENT POSITION")
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
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                Text("BK")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("BomKalkulator")
                    .font(.caption.weight(.semibold))
                Text("Trip resumed automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                withAnimation {
                    vm.cancelAutoResume()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
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
