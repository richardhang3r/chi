//
//  DeviceActivityMonitorExtension.swift
//  activityMonitorExtension
//
//  Created by Richard Hanger on 6/4/24.
//

//
//  DeviceActivityMonitorExtension.swift
//  deviceActivityMonitor
//
//  Created by Richard Hanger on 5/24/24.
//

import DeviceActivity
import ManagedSettings
import SwiftUI
import SwiftData

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Handle the start of the interval.
        if activity == DeviceActivityName("Daily") {
            ActivityMonitor.appyManagedSettings()
            NotificationManager.notifyFromActivityMonitor(message: "Daily Activiy Monitor Started")
        } else if activity == DeviceActivityName("BypassSchedule") {
            // for bypass we allow the user during the allotted time so clear restrictions
            let store = ManagedSettingsStore()
            store.clearAllSettings()
            //Task {
              //  await MainActor.run {
            Task {
                await MainActor.run {
                    let modelContext = MainModelContainer().makeContainer().mainContext
                    if let goal = try? modelContext.fetch(FetchDescriptor<Goal>()).first {
                        goal.updateSharedDefaults()
                        goal.userBypassed()
                        goal.updateCount += 1
                        modelContext.insert(goal)
                        do {
                            try modelContext.save()
                            NotificationManager.notifyFromActivityMonitor(message: "five minut3s begin now \(modelContext.hasChanges)")
                        } catch {
                            NotificationManager.notifyDeveloper(subtitle: "data error", message: error.localizedDescription.description)
                        }
                    } else {
                        NotificationManager.notifyFromActivityMonitor(message: "five fucks begin now")
                    }
                }
            }
             //   }
            //}

        } else {
            NotificationManager.notifyFromActivityMonitor(message: "wtf \(activity)")
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Handle the end of the interval.
        if activity == DeviceActivityName("Daily") {
            let store = ManagedSettingsStore()
            store.clearAllSettings()
            ActivityMonitor.appyManagedSettings()
            NotificationManager.notifyFromActivityMonitor(message: "Daily Activiy Monitor Ended")
        } else if activity == DeviceActivityName("BypassSchedule") {
            // interval ended,  apply restriction
            ActivityMonitor.appyManagedSettings()
        }
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        if event == DeviceActivityEvent.Name("Bypass") {
            // Handle the event reaching its threshold.
            NotificationManager.notifyFromActivityMonitor(message: "extra time expired")
            // they went over time, reapply restrictions
            ActivityMonitor.appyManagedSettings()
        } else {
            NotificationManager.notifyFromActivityMonitor(message: "wtf event \(event)")
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // Handle the warning before the interval starts.
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // Handle the warning before the interval ends.
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        if event == DeviceActivityEvent.Name("Bypass") {
            // Handle the warning before the event reaches its threshold.
            NotificationManager.notifyFromActivityMonitor(message: "two minutes remaining")
        }
    }
}
