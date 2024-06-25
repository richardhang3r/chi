//
//  MyUserDefaults.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//
//
//  UserDefaults.swift
//  strive
//
//  Created by Richard Hanger on 12/14/23.
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import CloudKit
import UIKit

extension UIColor {
    static let twitterBlue = UIColor.init(red: 21/255, green: 52/255, blue: 64/255, alpha: 1.0)
    static let twitterText = UIColor.init(red: 24/255, green: 161/255, blue: 214/255, alpha: 1.0)
    static let xLight = UIColor.init(red: 0/255, green: 185/255, blue: 255/255, alpha: 1.0)
}

private struct UserDefaultInfo<Value> {
    
    let suiteName = "group.hang3r.chi"
    var key: String
    var defaultValue: Value
    
    func get_no_default() -> Value? {
        guard let valueUntyped = UserDefaults(suiteName: suiteName)?.value(forKey: self.key) else {
            return nil
        }
        guard let value = valueUntyped as? Value else {
            return nil
        }
        return value
    }
    
    func get() -> Value {
        guard let valueUntyped = UserDefaults(suiteName: suiteName)?.value(forKey: self.key) else {
            return self.defaultValue
        }
        guard let value = valueUntyped as? Value else {
            return self.defaultValue
        }
        return value
    }
    
    func set(_ value: Value) {
        // TODO: How to return true or false for whether it was successully set?
        //return UserDefaults(suiteName: suiteName)?.set(value, forKey: self.key) != nil
        UserDefaults(suiteName: suiteName)?.set(value, forKey: self.key)
        UserDefaults(suiteName: suiteName)?.synchronize()
    }
    
    func delete() {
        // TODO: How to return true or false for whether it was successully set?
        //return UserDefaults(suiteName: suiteName)?.set(value, forKey: self.key) != nil
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: self.key)
    }
}


enum MyUserDefaults {
    
    
    private static var _motivation_pack = UserDefaultInfo(key: "mpack", defaultValue: 0)
    private static var _shield_message = UserDefaultInfo(key: "shield_message", defaultValue: "Goal Not Completed")
    private static var _enforced_goals = UserDefaultInfo(key: "enforced_goals", defaultValue: Data())
    private static var _selectedStreak = UserDefaultInfo(key: "selectedStreak", defaultValue: "")
    private static var _activityThresholdPassed = UserDefaultInfo(key: "activityThresholdPassed", defaultValue: 0.0)
    private static var _autoCloudSync = UserDefaultInfo(key: "syncEngineAuto", defaultValue: true)

    // enum GoalTypes
    private static var _healthTypeObserverQueries = UserDefaultInfo(key: "healthTypeQueriesRaw", defaultValue: [""])
    private static var sharedScopeSyncStateStorage = UserDefaultInfo(key: "sharedScopeSyncEngineState", defaultValue: Data())
    private static var privateScopeSyncStateStorage = UserDefaultInfo(key: "privateScopeSyncEngineState", defaultValue: Data())
    private static var screenTimeSelectionStorage = UserDefaultInfo(key: "screenTimeSelection", defaultValue: Data())
    private static var settingsStoreStorage = UserDefaultInfo(key: "managedSettingsStoreName", defaultValue: "default")
    private static var _bypassScreentime = UserDefaultInfo(key: "bypassScreetime", defaultValue: 0.0)
    //default 14400 seconds -> 4 hours
    private static var _allocatedTimeStorage = UserDefaultInfo(key: "allocatedTime", defaultValue: 960.0)
    private static var _shieldActionInProgress = UserDefaultInfo(key: "shieldActionProgress", defaultValue: false)
    private static var _userid = UserDefaultInfo(key: "useridcustom", defaultValue: "")

    static var globalUserId: String {
        get { return _userid.get() }
        set { _userid.set(newValue)}
    }
    
    static var healthTypeObserverQueries: [String] {
        get { return _healthTypeObserverQueries.get() }
        set { _healthTypeObserverQueries.set(newValue)}
    }
    
    static var shieldActionInProgress: Bool {
        get { return _shieldActionInProgress.get() }
        set { _shieldActionInProgress.set(newValue)}
    }
    
    static var activityThresholdPassed: TimeInterval {
        get { return _activityThresholdPassed.get() }
        set { _activityThresholdPassed.set(newValue)}
    }
    
    static var autoCloudSync: Bool {
        get { return _autoCloudSync.get() }
        set { _autoCloudSync.set(newValue)}
    }
    
    static var selectedStreak: String {
        get { return _selectedStreak.get() }
        set { _selectedStreak.set(newValue)}
    }
    
    static var allocatedScreemTime: TimeInterval {
        get { return _allocatedTimeStorage.get() }
        set { _allocatedTimeStorage.set(newValue)}
    }
    
    static var m_pack: Int {
        get { return _motivation_pack.get() }
        set { _motivation_pack.set(newValue)}
    }
    
    static var bypassTime: TimeInterval {
        get { return _bypassScreentime.get() }
        set { _bypassScreentime.set(newValue) }
    }
    
    static var shield_message: String {
        get { return _shield_message.get() }
        set { _shield_message.set(newValue) }
    }
    
    
    static var enforced_goals: Data {
        get { return _enforced_goals.get() }
        set { _enforced_goals.set(newValue) }
    }
    
    
    static var screenTimeSelection: Data? {
        get { return screenTimeSelectionStorage.get_no_default() }
        set {
            if (newValue != nil) {
                screenTimeSelectionStorage.set(newValue!)
            } else {
                screenTimeSelectionStorage.delete()
            }
        }
    }
    
    /// The last known state we got from the sync engine.
    //var stateSerialization: CKSyncEngine.State.Serialization?
    static var privateSyncState: Data? {
        get { return privateScopeSyncStateStorage.get_no_default() }
        set {
            if (newValue != nil) {
                privateScopeSyncStateStorage.set(newValue!)
            } else {
                privateScopeSyncStateStorage.delete()
            }
        }
    }
    
    static var sharedSyncState: Data? {
        get { return sharedScopeSyncStateStorage.get_no_default() }
        set {
            if (newValue != nil) {
                sharedScopeSyncStateStorage.set(newValue!)
            } else {
                sharedScopeSyncStateStorage.delete()
            }
        }
    }

    static func saveDatabaseState(scope: CKDatabase.Scope, state: CKSyncEngine.State.Serialization?) {
        // Used to encode codable to UserDefaults
        let encoder = PropertyListEncoder()
        if let data : Data = try? encoder.encode(state) {
            if (scope == CKDatabase.Scope.private) {
                MyUserDefaults.privateSyncState = data
            } else {
                MyUserDefaults.sharedSyncState = data
            }
        }
    }
    
    static func loadDatabaseState(scope: CKDatabase.Scope) -> CKSyncEngine.State.Serialization? {
        // Used to encode codable to UserDefaults
        let decoder = PropertyListDecoder()
        //
        let data : Data? = scope == CKDatabase.Scope.private ? MyUserDefaults.privateSyncState : MyUserDefaults.sharedSyncState
        // decode serialization state from opaque data
        let decoded = try? decoder.decode(CKSyncEngine.State.Serialization.self, from: data ?? Data())
        return decoded
    }
    
    static func load_enforced_goals() -> enforced_info {
        // Used to encode codable to UserDefaults
        //
        let decoder = PropertyListDecoder()
        
        //
        let data : Data? = MyUserDefaults.enforced_goals
        
        //
        let enforced = try? decoder.decode(enforced_info.self, from: data ?? Data())
        
        return enforced == nil ? enforced_info(goals: []) : enforced!
    }
    
    static func save_enforced_goals(enforced: enforced_info) {
        // Used to encode codable to UserDefaults
        let encoder = PropertyListEncoder()
        if let data : Data = try? encoder.encode(enforced) {
            MyUserDefaults.enforced_goals = data
        }
    }
    
    
    static func saveSelection(selection: FamilyActivitySelection) {
        // Used to encode codable to UserDefaults
        let encoder = PropertyListEncoder()
        if let data : Data = try? encoder.encode(selection) {
            MyUserDefaults.screenTimeSelection = data
        }
    }
    
    static var managedSettingsStore: String {
        get { return settingsStoreStorage.get() }
        set { settingsStoreStorage.set(newValue) }
    }
    
    static func loadSelection() -> FamilyActivitySelection {
        //
        let decoder = PropertyListDecoder()
        
        //
        let data : Data? = MyUserDefaults.screenTimeSelection
        
        //
        let sel : FamilyActivitySelection
        if (data != nil) {
            sel = try! decoder.decode(FamilyActivitySelection.self, from: data!)
        } else {
            sel = FamilyActivitySelection()
        }
        return sel
    }
    
    static func clear_all_enforcement() {
        MyUserDefaults.save_enforced_goals(enforced: enforced_info(goals: []))
        let enforced_goals = MyUserDefaults.load_enforced_goals()
        print("enforced count \(enforced_goals.goals.count)")
    }

    
}

struct enforced_info : Decodable,Encodable {
    var goals : [enforced_goal]
}




struct enforced_goal : Decodable,Encodable {
    // name of goal
    var goal_name : String
    // goal target
    var goal : Double
    // value of goal
    var value : Double
    // streak id
    var id : String
    var updated : TimeInterval
    var type : Int
    //var unit_name : String
    //var type : GoalTypes
    //var active : Bool
    /*
    /// Tokens that represent applications selected by the user.
    var applicationTokens: Set<ApplicationToken>
    /// Tokens that represent categories selected by the user.
    var categoryTokens: Set<ActivityCategoryToken>
    /// Tokens that represent web domains selected by the user.
    var webDomainTokens: Set<WebDomainToken>
     */
}
