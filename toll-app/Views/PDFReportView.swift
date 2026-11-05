import SwiftUI

struct PDFReportView: View {
    let trip: WorkTrip
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Text("PDF Report")
                .navigationTitle("PDF")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
