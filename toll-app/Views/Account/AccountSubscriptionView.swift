import SwiftUI

struct AccountSubscriptionView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var isRestoring = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label(purchaseManager.isPremium
                          ? lang.t(nb: "Pro — Aktiv", en: "Pro — Active")
                          : lang.t(nb: "Gratis plan", en: "Free plan"),
                          systemImage: purchaseManager.isPremium ? "checkmark.seal.fill" : "star.fill")
                        .foregroundStyle(purchaseManager.isPremium ? .green : .primary)
                    Spacer()
                }
            } footer: {
                Text(purchaseManager.isPremium
                     ? lang.t(nb: "Du har ubegrenset tilgang.", en: "You have unlimited access.")
                     : lang.t(nb: "Oppgrader for ubegrensede søk og rapporter.", en: "Upgrade for unlimited searches and reports."))
            }

            if !purchaseManager.isPremium {
                Section {
                    Button {
                        Task {
                            isRestoring = true
                            await purchaseManager.restorePurchases()
                            isRestoring = false
                        }
                    } label: {
                        Label(isRestoring
                              ? lang.t(nb: "Gjenoppretter...", en: "Restoring...")
                              : lang.t(nb: "Gjenopprett kjøp", en: "Restore Purchase"),
                              systemImage: "arrow.clockwise.circle.fill")
                    }
                    .disabled(isRestoring)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lang.t(nb: "Abonnement", en: "Subscription"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
