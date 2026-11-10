import SwiftUI
import SwiftData

struct AccountPanel: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("driverName") private var driverName: String = ""
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("accountantEmail") private var accountantEmail: String = ""
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }

    private var avatarInitials: String {
        let parts = driverName.split(separator: " ").compactMap { $0.first.map { String($0) } }
        if parts.count >= 2 { return (parts[0] + parts[1]).uppercased() }
        return String(driverName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    quickCards
                    menuList
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(lang.t(nb: "Konto", en: "Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(lang.t(nb: "Lukk", en: "Close")) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            appState.showAccountPanel = false
                        }
                    }
                }
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 56, height: 56)
                Text(avatarInitials.isEmpty ? "?" : avatarInitials)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(driverName.isEmpty ? lang.t(nb: "Ditt navn", en: "Your name") : driverName)
                    .font(.headline)
                    .foregroundStyle(driverName.isEmpty ? .secondary : .primary)
                if !accountantEmail.isEmpty {
                    Text(accountantEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !companyName.isEmpty {
                    Text(companyName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var quickCards: some View {
        HStack(spacing: 12) {
            NavigationLink {
                AccountProfilView()
            } label: {
                quickCard(
                    icon: "person",
                    title: lang.t(nb: "Profil", en: "Profile"),
                    subtitle: lang.t(nb: "Personopplysninger", en: "Personal info")
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AccountVehicleView()
            } label: {
                quickCard(
                    icon: "car.fill",
                    title: lang.t(nb: "Kjøretøy", en: "Vehicles"),
                    subtitle: lang.t(nb: "Dine kjøretøy", en: "Your vehicles")
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func quickCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(.blue)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var menuList: some View {
        VStack(spacing: 0) {
            menuRow(icon: "lock.fill", color: .gray,
                    title: lang.t(nb: "Innlogging og sikkerhet", en: "Login & Security")) {
                AccountPlaceholderView(title: lang.t(nb: "Innlogging og sikkerhet", en: "Login & Security"))
            }

            Divider().padding(.leading, 52)

            menuRow(icon: "gearshape.fill", color: .gray,
                    title: lang.t(nb: "Innstillinger", en: "Settings")) {
                AccountSettingsView()
            }

            Divider().padding(.leading, 52)

            menuRow(icon: "doc.text.fill", color: .blue,
                    title: lang.t(nb: "Abonnement", en: "Subscription")) {
                AccountSubscriptionView()
            }

            Divider().padding(.leading, 52)

            menuRow(icon: "envelope.fill", color: .blue,
                    title: lang.t(nb: "Innboks", en: "Inbox"),
                    badge: nil) {
                AccountPlaceholderView(title: lang.t(nb: "Innboks", en: "Inbox"))
            }

            Divider().padding(.leading, 52)

            menuRow(icon: "bell.fill", color: .orange,
                    title: lang.t(nb: "Kundeservice", en: "Customer service")) {
                AccountSupportView()
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func menuRow<Destination: View>(
        icon: String,
        color: Color,
        title: String,
        badge: Int? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var footer: some View {
        Text("BomKalkulator · Versjon \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
    }
}
