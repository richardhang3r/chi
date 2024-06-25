//
//  ShieldConfigurationExtension.swift
//  shieldConfigurationExtension
//
//  Created by Richard Hanger on 6/4/24.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    
    private func getExpectedShield() -> ShieldConfiguration
    {
        let goalsLeft = getShieldExtensionResults()
        let _ : String = MyUserDefaults.shield_message
        
        // just deal with one goal max
        let shield_config : ShieldConfiguration
        if let goal = goalsLeft.failedGoals.first {
            // failure
            var subtitle : String = ""
            var type : GoalType? = nil
            let _ = Date(timeIntervalSinceReferenceDate: goal.updated)
            subtitle = "\(Int(goal.goal - goal.value)) \(goal.goal_name) needed"
            if let rawClassType = GoalType(rawValue: goal.type) {
                type = rawClassType
            }
            
            shield_config =  ShieldConfiguration(
                backgroundBlurStyle: UIBlurEffect.Style.regular,
                backgroundColor: UIColor.beige,
                icon: UIImage(systemName: "\(type?.iconName ?? "questionmark")")?.withTintColor(UIColor.accent),
                title: ShieldConfiguration.Label(text: String(format: "\(type?.description ?? "?") to unlock"), color: .accent),
                subtitle: ShieldConfiguration.Label(text: String(format: "\(subtitle)"), color: .accent),
                primaryButtonLabel: ShieldConfiguration.Label(text: "go", color: .label),
                secondaryButtonLabel: ShieldConfiguration.Label(text: "five minute override", color: .accent)
            )
        } else {
            // success
            shield_config =  ShieldConfiguration(
                backgroundBlurStyle: UIBlurEffect.Style.regular,
                icon: UIImage(systemName: "laurel.leading")?.withTintColor(UIColor.green),
                title: ShieldConfiguration.Label(text: "congratulations", color: .accent),
                subtitle: ShieldConfiguration.Label(text: String(format: "goal completed"), color: .accent),
                primaryButtonLabel: ShieldConfiguration.Label(text: "proceed", color: .accent),
                secondaryButtonLabel: nil
            )
        }
        return shield_config
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Customize the shield as needed for applications.
        getExpectedShield()
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for applications shielded because of their category.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        // Customize the shield as needed for web domains.
        ShieldConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        // Customize the shield as needed for web domains shielded because of their category.
        ShieldConfiguration()
    }
}
