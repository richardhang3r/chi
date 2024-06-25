//
//  Config.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import Foundation
import CloudKit
import SwiftData
import os.log


public class MainModelContainer {
    
    public let schema = SwiftData.Schema([
        Goal.self,
    ])
    
    public func makeContainer() -> ModelContainer {
        
        let configuration = ModelConfiguration(
            "MainContainer",
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.hang3r.chi"),
            cloudKitDatabase: .none)
        
        return try! ModelContainer(for: schema, configurations: configuration)
    }
}


enum Config {
    /// iCloud container identifier.
    /// Update this if you wish to use your own iCloud container.
    static let cloudContainerIdentifier = "iCloud.com.example.hang3r.apple-samplecode.CloudKitShareU9A674PK7L"
    static let cloudContainer : CKContainer =  CKContainer(identifier: Config.cloudContainerIdentifier)
    
    //static let modelContainer = try! ModelContainer(for: schema, configurations: [.init(isStoredInMemoryOnly: false,cloudKitDatabase: .none)])
    
    static func forceSetUniqueUserId(id: String) {
        //UserDefaults.standard.setValue(id, forKey: "UserId")
        MyUserDefaults.globalUserId = id
    }
    
    static func setUniqueUserId() {
        if let user_id = UserDefaults.standard.value(forKey: "UserId") {
            // great,  already set
            print("UserId already set \(user_id)")
        } else {
            MyUserDefaults.globalUserId = UUID().uuidString
            //UserDefaults.standard.setValue(UUID().uuidString, forKey: "UserId")
        }
    }
}

var currentUserName: String? {
    get{
        UserDefaults.standard.string(forKey: "UserName") ?? "anon"
    }
}

var globalUserId: String  {
    get{
        MyUserDefaults.globalUserId
        //UserDefaults.standard.string(forKey: "UserId") ?? "balls"
    }
}

extension Notification.Name {
    static let zoneCacheDidChange = Notification.Name("zoneCacheDidChange")
    static let sharedRecordsDidChange = Notification.Name("cloudUpdateInformation")
    static let healthKitDataUpdate = Notification.Name("healthKitUpdate")
    static let healthTypeChanged = Notification.Name("healthTypeChanged")
    static let zoneDidSwitch = Notification.Name("zoneDidSwitch")
    static let localStreakChange = Notification.Name("localStreakChange")
    static let localUserChange = Notification.Name("localUserChange")
    static let recordsChanged = Notification.Name("recordsChanged")
    static let recordsDeleted = Notification.Name("recordsDeleted")
    static let recordsSaved = Notification.Name("recordsSaved")
    static let activityMonitorEvent = Notification.Name("activityMonitorEvent")
    static let recordsInvalid = Notification.Name("recordsInvalid")
}

enum UserInfoKey: String {
    case sharedRecordChanges, zoneCacheChanges, zoneSwitched, healthKitChanges, healthTypeChanged, localStreakChange, localUserChange, recordsChanged, recordsDeleted, recordsSaved, recordsInvalid, activityMonitorEvent
}
