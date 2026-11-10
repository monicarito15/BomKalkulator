//
//  Date+RushHour.swift
//  toll-app
//
//  Extension for Date to detect Norwegian rush hour times

import Foundation

extension Date {
  
    func isRushHour() -> Bool {
        let calendar = Calendar.current
        
        // Check if it's a weekday (Monday = 2, Friday = 6)
        let weekday = calendar.component(.weekday, from: self)
        guard weekday >= 2 && weekday <= 6 else {
            return false // Weekend - no rush hour
        }
        
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let totalMinutes = hour * 60 + minute
        
        // Morning rush hour: 6:30 - 9:00 (390 - 540 minutes)
        let morningStart = 6 * 60 + 30  // 390 minutes
        let morningEnd = 9 * 60         // 540 minutes
        
        // Afternoon rush hour: 14:30 - 17:00 (870 - 1020 minutes)
        // Bergen (Ferde AS) starts at 14:30 — use earliest Norwegian rush hour as lower bound
        let afternoonStart = 14 * 60 + 30  // 870 minutes
        let afternoonEnd = 17 * 60          // 1020 minutes
        
        return (totalMinutes >= morningStart && totalMinutes < morningEnd) ||
               (totalMinutes >= afternoonStart && totalMinutes < afternoonEnd)
    }
    
    // Returns a descriptive rush hour message
    func rushHourMessage() -> String {
        let lang = LanguageManager.shared
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let totalMinutes = hour * 60 + minute

        // Morning rush hour: 6:30 - 9:00
        if totalMinutes >= 6 * 60 + 30 && totalMinutes < 9 * 60 {
            return lang.t(nb: "Rushtid: 6:30 - 9:00. Prisene er høyere i rushtiden.",
                          en: "Rush Hour: 6:30 - 9:00. Prices are higher during peak times.")
        }

        // Afternoon rush hour: 14:30 - 17:00
        if totalMinutes >= 14 * 60 + 30 && totalMinutes < 17 * 60 {
            return lang.t(nb: "Rushtid: 14:30 - 17:00. Prisene er høyere i rushtiden.",
                          en: "Rush Hour: 14:30 - 17:00. Prices are higher during peak times.")
        }

        return ""
    }
    
  
    //Returns: Time range string (e.g., "6:30 - 9:00") or nil if not in rush hour
    func rushHourTimeRange() -> String? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let totalMinutes = hour * 60 + minute
        
        // Morning rush hour
        if totalMinutes >= 6 * 60 + 30 && totalMinutes < 9 * 60 {
            return "6:30 - 9:00"
        }
        
        // Afternoon rush hour
        if totalMinutes >= 14 * 60 + 30 && totalMinutes < 17 * 60 {
            return "14:30 - 17:00"
        }
        
        return nil
    }
}
