//
//  RushHourWarningView.swift
//  toll-app
//
//  A reusable warning banner that displays when a selected time is during rush hour
//

import SwiftUI

struct RushHourWarningView: View {
    let date: Date
    @ObservedObject private var lang = LanguageManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Clock icon
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(.red)

            // Warning text
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t(nb: "Rushtid", en: "Rush Hour"))
                    .font(.headline)
                    .foregroundStyle(.red)

                Text(date.rushHourMessage())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}


#Preview("Rush Hour Warning - Morning") {
    VStack(spacing: 20) {
        // Morning rush hour
        RushHourWarningView(date: {
            var components = DateComponents()
            components.year = 2026
            components.month = 3
            components.day = 24  // Monday
            components.hour = 7
            components.minute = 30
            return Calendar.current.date(from: components)!
        }())
        
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}

#Preview("Rush Hour Warning - Afternoon") {
    VStack(spacing: 20) {
        // Afternoon rush hour
        RushHourWarningView(date: {
            var components = DateComponents()
            components.year = 2026
            components.month = 3
            components.day = 24  // Monday
            components.hour = 16
            components.minute = 0
            return Calendar.current.date(from: components)!
        }())
        
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
}

#Preview("Calculator View Context") {
    ScrollView {
        VStack(spacing: 20) {
            // Simulate Route & Time section
            VStack(alignment: .leading, spacing: 8) {
                Text("ROUTE & TIME")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                
                VStack {
                    Text("Oslo → Bergen")
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
            
            // Rush hour warning
            RushHourWarningView(date: {
                var components = DateComponents()
                components.year = 2026
                components.month = 3
                components.day = 24
                components.hour = 7
                components.minute = 30
                return Calendar.current.date(from: components)!
            }())
            
            // Simulate Vehicle Details section
            VStack(alignment: .leading, spacing: 8) {
                Text("VEHICLE DETAILS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                
                VStack {
                    Text("Car, Electric, Autopass")
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
            
            Spacer()
        }
        .padding(.vertical, 20)
    }
    .background(Color(.systemGroupedBackground))
}
