//
//  ShieldActionExtension.swift
//  shieldActionExtension
//
//  Created by Richard Hanger on 6/4/24.
//

import ManagedSettings
import SwiftData

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    
    
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        
        let goalsLeft = getShieldExtensionResults()
        
        
        // Handle the action as needed.
        switch action {
        case .primaryButtonPressed:
            // if no goals are left,  this was a success
            if goalsLeft.failedGoals.isEmpty {
                let settingsStore = ManagedSettingsStore()
                settingsStore.clearAllSettings()
            } else {
                NotificationManager.notifyFromShieldExtension()
            }
            completionHandler(.none)
        case .secondaryButtonPressed:
            // send alert in 5 minutes
            ActivityMonitor.beginBypassMonitor(totalMinutes: 15, warningTime: 5, appToken: application)
            //let settingsStore = ManagedSettingsStore()
            //settingsStore.clearAllSettings()
            // clear settings and wait
            // activity monitor should clear settings
            //settingsStore.clearAllSettings()
            completionHandler(.none)
        @unknown default:
            fatalError()
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
}
