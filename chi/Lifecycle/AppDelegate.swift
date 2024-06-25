//
//  AppDelegate.swift
//  track
//
//  Created by Richard Hanger on 5/29/24.
//

import Foundation
import CloudKit
import NotificationCenter
import HealthKit

class MyAppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private var currentUserRecordID: CKRecord.ID?
    

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handleNotification(userInfo: userInfo)
        completionHandler(.newData)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo)
        completionHandler()
    }

    private func handleNotification(userInfo: [AnyHashable: Any]) {
        if let view = userInfo["view"] as? String {
            DispatchQueue.main.async {
                switch view {
                case "message", "home":
                    break;
                case "workout":
                    Router.shared.path.append(view)
                    break
                    //Router.shared.selectedStreak = "workout"
                default:
                    break;
                }
            }
        }
    }
    
    func application(_ application: UIApplication, configurationForConnecting
                     connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        
        
        // Create a scene configuration object for the
        // specified session role.
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setBadgeCount(0, withCompletionHandler:  {_ in
            print("Set Badge Count to 0\n")
        })
        // Set the configuration's delegate class to the
        // scene delegate that implements the share
        // acceptance method.
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    // If your iCloud container identifier isn't in the form "iCloud.<bundle identifier>",
    // use CKContainer(identifier: <your container ID>) to create the container.
    // An iCloud container identifier is case-sensitive and must begin with "iCloud.".
    func application( _ application: UIApplication,
                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Observe .zoneCacheDidChange and .zoneDidSwitch to update the topic cache, if necessary.
        // Register for remote notifications. The local caches rely on subscription notifications,
        // so you need to grant notifications when the system asks.
        //
        
        let healthTypes : [String] = MyUserDefaults.healthTypeObserverQueries
        for healthType in healthTypes {
            if !healthType.isEmpty  {
                HealthData.healthConfigureBackgroundQuery(for: healthType)
            }
        }

        /*
        Task {
            if let goals = await Goal.getAllGoals() {
                var datatypes : [String] = []
                for goal in goals {
                    if goal.type.supportHealthKit {
                        datatypes.append(goal.type.healthIdentifier.rawValue)
                    }
                }
                HealthData.requestHealthDataAccessIfNeeded(dataTypes: datatypes) {success in
                    if success {
                        for datatype in datatypes {
                            DispatchQueue.main.async {
                                print("configuring background query for \(datatype)")
                                HealthData.healthConfigureBackgroundQuery(for: datatype)
                            }
                        }
                    }
                }
            }
        }
         */
        print("launch reason! : \(String(describing: launchOptions?.debugDescription))")
            //NotificationManager.notifyFromActivityMonitor(message: "launch:\(String(describing: launchOptions?.description))")
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
            if let error = error {
                print("notificationCenter.requestAuthorization returns error: \(error)")
            }
            if granted != true {
                print("notificationCenter.requestAuthorization is not granted!")
            }
        }
        application.registerForRemoteNotifications()
        return true
    }
    
}
