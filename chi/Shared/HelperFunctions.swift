//
//  HelperFunctions.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import Foundation
import SwiftUI
import CloudKit
import BackgroundTasks
import SwiftData

func weekdayString(date: Date) -> String {
    let dateFormatter = DateFormatter()
    
    // dateFormatter.dateFormat = "yyyyMMdd"
    // dateFormatter.dateStyle = .long
    // dateFormatter.timeStyle = .none
    dateFormatter.dateFormat = "EEE"
    dateFormatter.locale = Locale(identifier: "en_US")
    return  dateFormatter.string(from: date)
}

func daysAgo(from date: Date) -> Int? {
    let calendar = Calendar.current
    let today = Date()

    let components = calendar.dateComponents([.day], from: date, to: today)
    return components.day
}


func getDateStringShort(date: Date) -> String {
    let calendar = Calendar.current
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd" // Format to extract only date without time
    
    // save previous total from day
    let components = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate))
    guard let date = calendar.date(from: components) else {
        // formatted date - yyyy-mm-dd
        return "unknown"
    }
    return dateFormatter.string(from: date)
}

func get_time_of_day_UTC(time: TimeInterval) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm a"
    dateFormatter.locale = Locale(identifier: "en_US")
    // value passed in is raw seconds into the current day.
    // without specifying UTC time zone it tries to account for current time zones delay
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return  dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: time))
}

func get_full_readable_time_LOCAL(date: Date) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd h:mm a"
    dateFormatter.locale = Locale(identifier: "en_US")
    // value passed in is raw seconds into the current day.
    // without specifying UTC time zone it tries to account for current time zones delay
    //dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return  dateFormatter.string(from: date)
}

func get_time_of_day_LOCAL(date: Date?) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "h:mm a"
    dateFormatter.locale = Locale(identifier: "en_US")
    // value passed in is raw seconds into the current day.
    // without specifying UTC time zone it tries to account for current time zones delay
    //dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    if let validDate = date {
        return  dateFormatter.string(from: validDate)
    } else {
        return  "unknown"
    }
}

func getLastNumDays(_ num_days: Int) -> [Date] {
    let calendar = Calendar.current
    let currentDate = Date()
    
    // Generate a range of dates for the last 7 days
    let lastSevenDays = (0...num_days).map { index in
        return calendar.date(byAdding: .day, value: -index, to: currentDate)!
    }
    
    return lastSevenDays
}

func isSameDay(_ date1: Date,_ date: Date) -> Bool {
    let calendar = Calendar.current
    //let dateFromTimeInterval = Date(timeIntervalSince1970: timeInterval)
    return calendar.isDate(date1, inSameDayAs: date)
}

func infoRow(label: String, value: String, icon: String) -> some View {
    return HStack {
        Image(systemName: icon)
            .foregroundColor(.blue)
        Text(label + ":")
            .font(.subheadline)
            .foregroundColor(.secondary)
        Spacer()
        Text(value)
            .font(.subheadline)
            .foregroundColor(.primary)
    }
}

func getDbType(recordID: CKRecord.ID) -> CKDatabase.Scope {
    let dbType: CKDatabase.Scope
    let zone_owner_name = recordID.zoneID.ownerName
    if zone_owner_name == CKCurrentUserDefaultName {
        // The record is in the private database
        print("Record \(recordID.debugDescription) is in the private database")
        dbType = CKDatabase.Scope.private
    } else if zone_owner_name == CKRecordZone.ID.default.ownerName {
        // The record is in the public database
        print("Record \(recordID.debugDescription) is in the public database")
        dbType = CKDatabase.Scope.public
    } else {
        // The record is in a shared database
        print("Record \(recordID.debugDescription) is in a shared database")
        dbType = CKDatabase.Scope.shared
    }
    
    return dbType
}

struct ShieldExtensionResults {
    var failedGoals : [enforced_goal] = []
}

func getShieldExtensionResults() -> ShieldExtensionResults {
    let enforced_goals = MyUserDefaults.load_enforced_goals()
    var results : ShieldExtensionResults = ShieldExtensionResults()
    for goal in enforced_goals.goals {
        let time = Date(timeIntervalSinceReferenceDate: goal.updated)
        // don't count stale goals as complete.  user needs to open app to update values
        if (!Calendar.current.isDateInToday(time) || goal.value < goal.goal) {
            results.failedGoals.append(goal)
        }
    }
    return results
}

func getDatabase(for recordId: CKRecord.ID, from container: CKContainer) -> CKDatabase {
    
    let database: CKDatabase
    let type = getDbType(recordID: recordId)
    switch(type) {
    case CKDatabase.Scope.private:
        database = container.privateCloudDatabase
        break;
    case CKDatabase.Scope.shared:
        database = container.sharedCloudDatabase
        break;
    case CKDatabase.Scope.public:
        database = container.publicCloudDatabase
        break;
    default:
        fatalError("Unknown Database")
        break;
    }
    return database
}

func scheduleAppRefresh(time: Date) {
    
    let request = BGAppRefreshTaskRequest(identifier: "com.hang3r.chi.refresh")
    //request.earliestBeginDate = .now.addingTimeInterval(24 * 3600)
    request.earliestBeginDate = time
    do {
        try BGTaskScheduler.shared.submit(request)
        print("Scheduled Background Task!!")
    } catch {
        print("Could not schedule app refresh: \(error)")
    }
}

func scheduleAppMidnight() {
    let request = BGAppRefreshTaskRequest(identifier: "com.hang3r.chi.midnight")
    request.earliestBeginDate = nextMidnight()
    do {
        try BGTaskScheduler.shared.submit(request)
        print("Scheduled Background Task!!")
    } catch {
        print("Could not schedule app refresh: \(error)")
    }
}
func scheduleAppCheckin() -> Bool {
    let request = BGAppRefreshTaskRequest(identifier: "com.hang3r.chi.checkin")
    // start in 60 seconds
    
    request.earliestBeginDate = .now.addingTimeInterval(60)
    //request.earliestBeginDate = nextMidnight()
    do {
        try BGTaskScheduler.shared.submit(request)
        print("Scheduled Background Task!!")
        return true
    } catch {
        print("Could not schedule app refresh: \(error)")
        return false
    }
}

func scheduleAppRefresh() -> Bool {
    let request = BGAppRefreshTaskRequest(identifier: "com.hang3r.chi.refresh")
    // start in 60 seconds
    
    request.earliestBeginDate = .now.addingTimeInterval(60)
    //request.earliestBeginDate = nextMidnight()
    do {
        try BGTaskScheduler.shared.submit(request)
        print("Scheduled Background Task!!")
        return true
    } catch {
        print("Could not schedule app refresh: \(error)")
        return false
    }
}

private func nextMidnight() -> Date {
    var calendar = Calendar.current
    calendar.timeZone = .current
    let now = Date()
    if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
        return midnight
    }
    return now.addingTimeInterval(86400) // Fallback to 24 hours later if calculation fails
}


private func nextMorning() -> Date {
    var calendar = Calendar.current
    calendar.timeZone = .current
    let now = Date()
    if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 3, minute: 0), matchingPolicy: .nextTime) {
        return midnight
    }
    return now.addingTimeInterval(86400) // Fallback to 24 hours later if calculation fails
}
