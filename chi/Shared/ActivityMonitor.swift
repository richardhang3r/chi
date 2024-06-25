//
//  ActivityMonitor.swift
//  track
//
//  Created by Richard Hanger on 5/24/24.
//

import Foundation
import DeviceActivity
import ManagedSettings


class ActivityMonitor {
    
    static public func stopSchedule() {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
    }
    
    static public func appyManagedSettings() {
        let selection = MyUserDefaults.loadSelection()
        let store = ManagedSettingsStore()
        // still should be enforced becuase some remain in enforced list
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }
    
    static public func setDailyEvent(thresholdMinutes: Int) {
        print("Setting up the schedule")
        print("Current time is: ", Calendar.current.dateComponents([.hour, .minute], from: Date()).hour!)

        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .init("Scheduled"): DeviceActivityEvent(
                threshold: DateComponents(minute: thresholdMinutes),
                includesPastActivity: true
            )
        ]
        
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        let center = DeviceActivityCenter()
        center.stopMonitoring()
        do {
            print("Started Monitoring")
            try center.startMonitoring(.init("Daily"), during: schedule, events: events)
        } catch {
            print("Error occured while started monitoring: ", error)
        }
    }
    
    static public func beginBypassMonitor(totalMinutes: Int, warningTime: Int = 0, appToken: ApplicationToken) {
        
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .init("Bypass"): DeviceActivityEvent(
                applications: Set(arrayLiteral: appToken), 
                threshold: DateComponents(minute: warningTime),
                includesPastActivity: false
            )
        ]
        
        // Create DateComponents for the current time
        let now = Date.now
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        // Create DateComponents for X minutes later
        let minutesLater = calendar.date(byAdding: .minute, value: totalMinutes, to: now)!
        let minutesLaterComponents = calendar.dateComponents([.hour, .minute], from: minutesLater)
        // Create DeviceActivitySchedule
        let activitySchedule = DeviceActivitySchedule(
            intervalStart: nowComponents,
            intervalEnd: minutesLaterComponents,
            repeats: false,
            warningTime: DateComponents(minute: 2)
        )

        let center = DeviceActivityCenter()
        do {
            print("Started Bypass Monitoring")
            try center.startMonitoring(.init("BypassSchedule"), during: activitySchedule, events: events)
        } catch {
            print("Error occured while started monitoring: ", error)
        }
    }
}
