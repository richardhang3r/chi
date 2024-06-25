//
//  AppManager.swift
//  track
//
//  Created by Richard Hanger on 5/24/24.
//

import Foundation
import SwiftData
import CloudKit
import UIKit
import os.log
import SwiftUI

class Router: ObservableObject {
    @Published var path: NavigationPath = NavigationPath()
    @Published var pendingShare: CKShare.Metadata?
    static let shared: Router = Router()
    func popToRoot(){
        print("path count \(path.count)")
        path.removeLast(path.count) // pop to root
    }
}

class ViewModel: ObservableObject {
    @Published var path = NavigationPath()
    
    func popToRoot(){
        path.removeLast(path.count) // pop to root
    }
}

class RouterHome: ObservableObject {
    @Published var path: NavigationPath = NavigationPath()
    static let shared: RouterHome = RouterHome()
}

class NotificationManager: ObservableObject {
    @Published var isPermissionGranted: Bool = false

    static func notifyFromShieldExtension() {
        let content = UNMutableNotificationContent()
        content.title = "click to begin"
        content.body = "continue progress toward goal"
        content.userInfo = ["view": "workout"] // Custom data to navigate to the specific view
        let request = UNNotificationRequest(identifier: "ShieldExtension", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
    }
    
    static func notifyDeveloper(subtitle: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "debug"
        content.subtitle = "\(subtitle)"
        content.body = "\(message)"
        let request = UNNotificationRequest(identifier: "ActivityMonitor\(Date.now.description)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
    }
    
    static func notifyFromActivityMonitor(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "activity monitor"
        content.body = "\(message)"
        let request = UNNotificationRequest(identifier: "ActivityMonitor\(Date.now.description)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error)")
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.requestAuthorization()
                case .denied:
                    self.isPermissionGranted = false
                    // Handle the case where the user has denied notifications
                case .authorized, .provisional, .ephemeral:
                    self.isPermissionGranted = true
                @unknown default:
                    break
                }
            }
        }
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Handle the error here
                    print("Request Authorization Failed (\(error), \(error.localizedDescription))")
                }
                self.isPermissionGranted = granted
            }
        }
    }
}

