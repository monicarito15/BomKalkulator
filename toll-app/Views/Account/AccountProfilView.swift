import SwiftUI

struct AccountProfilView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @AppStorage("driverName") private var driverName: String = ""
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("accountantEmail") private var accountantEmail: String = ""

    var body: some View {
        List {
            Section {
                LabeledContent(lang.t(nb: "Sjåførnavn", en: "Driver name")) {
                    TextField(lang.t(nb: "Ditt navn", en: "Your name"), text: $driverName)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(lang.t(nb: "Selskap", en: "Company")) {
                    TextField(lang.t(nb: "Selskapsnavn", en: "Company name"), text: $companyName)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(lang.t(nb: "Regnskapsfører e-post", en: "Accountant email")) {
                    TextField("email@example.com", text: $accountantEmail)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            } footer: {
                Text(lang.t(nb: "Brukes i PDF-rapportene dine.", en: "Used in your PDF reports."))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lang.t(nb: "Profil", en: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
