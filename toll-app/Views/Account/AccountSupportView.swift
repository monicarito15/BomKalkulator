import SwiftUI

struct AccountSupportView: View {
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        List {
            Section {
                Button {
                    openMail(subject: "BomKalkulator - Support")
                } label: {
                    Label(lang.t(nb: "Send e-post til support", en: "Send email to support"),
                          systemImage: "envelope.fill")
                }

                Button {
                    openMail(subject: "BomKalkulator - Feilrapport")
                } label: {
                    Label(lang.t(nb: "Rapporter en feil", en: "Report a Bug"),
                          systemImage: "exclamationmark.bubble.fill")
                }
                .foregroundStyle(.orange)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(lang.t(nb: "Kundeservice", en: "Customer Service"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openMail(subject: String) {
        let email = "carolinamera1985@gmail.com"
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
