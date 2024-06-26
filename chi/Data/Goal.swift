//
//  goal.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

import Foundation
import SwiftData
import CloudKit
import os.log


struct DataRecord : Codable {
    var value : Double = 0.0
    var timeCompleted : TimeInterval = Date.distantFuture.timeIntervalSinceReferenceDate
    var goalLost : TimeInterval = Date.distantFuture.timeIntervalSinceReferenceDate
    var bypasses :  Int = 0
}

struct Peer : Codable, Identifiable {
    //unique
    var id: String = UUID().uuidString
    var userId: String = globalUserId
    var name: String = currentUserName ?? "unknown"
    var dataRecord : [String:DataRecord] = [:]
    var currentStreak : Int = 0
    var bestStreak : Int = 0
    var lastUpdate: Date = Date.distantPast
}

extension Peer {
    func getGoalStatus(target: Double, date: Date = Date.now) -> GoalStatus {
        let status : GoalStatus
        if let today = self.dataRecord[getDateStringShort(date: date)] {
            if today.timeCompleted < today.goalLost {
                // passed
                status = .passed
            //} else if (target > today.value && today.goalLost == Date.distantFuture.timeIntervalSinceReferenceDate) {
            } else {
                // not yet complete
                status = .pending
            } 
            /*
            else {
                // failed
                status = .failed
            }
             */
        } else {
            status = .absent
        }
        return status
    }
    
    mutating func setup()
    {
        self.setTodaysData(dr: self.getTodaysData())
    }
    
    mutating func setNewValue(val: Double,date: Date, target: Double) -> Bool
    {
        let justCompleted: Bool
        let formattedDate = getDateStringShort(date: date)
        
        if  (self.dataRecord[formattedDate] == nil) {
            // a new day!
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)
            let status = self.getGoalStatus(target: target, date: yesterday!)
            // do we need to reset our streak count?
            if (status != .passed) {
                if self.currentStreak > self.bestStreak {
                    self.bestStreak = self.currentStreak
                }
                self.currentStreak = 0
            }
        }
        
        
        var dr = self.dataRecord[formattedDate, default: DataRecord()]
        dr.value = val
        if dr.timeCompleted == Date.distantFuture.timeIntervalSinceReferenceDate && dr.value >= target {
            dr.timeCompleted = Date.now.timeIntervalSinceReferenceDate
            justCompleted = true
            // if this counts as a completion
            if (dr.timeCompleted < dr.goalLost) {
                self.currentStreak += 1
            }
        } else {
            justCompleted = false
        }
        
        print("set \(val) from \(formattedDate) to \(self.name)")
        // set back to itself
        self.dataRecord[formattedDate] = dr
        
        return justCompleted
    }
    
    mutating func appBypass() {
        let formattedDate = getDateStringShort(date: Date.now)
        var dr = self.dataRecord[formattedDate, default: DataRecord()]
        if dr.goalLost == Date.distantFuture.timeIntervalSinceReferenceDate {
            dr.goalLost = Date.now.timeIntervalSinceReferenceDate
        }
        dr.bypasses += 1
        self.lastUpdate = Date.now
        // set back to itself
        self.dataRecord[formattedDate] = dr
    }
    
    
    mutating func setTodaysData(dr: DataRecord) {
        self.dataRecord[getDateStringShort(date: Date.now)] = dr
    }
    
    func getTodaysData() -> DataRecord {
        return self.dataRecord[getDateStringShort(date: Date.now),default: DataRecord()]
    }
    
    func getTodaysValue() -> Double {
        let today = self.dataRecord[getDateStringShort(date: Date.now),default: DataRecord()]
        return today.value
    }
}

@Model
final class Goal : Sendable {
    
    // each user keeps copy of this id as goalId
    @Attribute(.unique)
    let ident: String = UUID().uuidString
    
    // participants
    var participants : [Peer] = []
    
    // name of goal
    var name : String = "classic"
    
    // target to reach
    var target : Double = GoalType.squat.defaultValue
    
    // cloudkit record data
    var record : ServerRecordData = ServerRecordData()
    
    var isParticipating : Bool = false
    // when goal started
    var startTime : Date = Date.now

    // end time if applicable
    var endTime : Date = Date.distantFuture
    
    // has goal been deleted by this user
    var pendingDelete: Bool = false

    // passcode for goal
    var goalPasscode : String = ""
    
    // passcode for goal
    var screenTimeMinutes : Int = 15

    // passcode for goal
    var updateCount : Int = 0
    
    // name
    var type: GoalType {
        get { GoalType(rawValue: _type)! }
        set { _type = newValue.rawValue }
    }
    private var _type: GoalType.RawValue = GoalType.squat.rawValue
    
    
    var enforceType: EnforcementType {
        get { EnforcementType(rawValue: _enforceType)! }
        set { _enforceType = newValue.rawValue }
    }
    private var _enforceType: EnforcementType.RawValue = EnforcementType.blockAppsFirst.rawValue

    
    var timestamp: Date = Date.now
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
    
    init?(record: CKRecord) {
        if (record.recordType != Goal.recordType) {
            Logger.dataModel.warning("Invalid record type \(record.recordType) in user record")
            return nil
        }
        self.ident = record.recordID.recordName
        self.mergeFromServerRecord(record)
        self.setLastKnownRecordIfNewer(record)
    }
    
    init(id: String = UUID().uuidString, type: GoalType = GoalType.squat, userid: String = globalUserId) {
        self._type = type.rawValue
        self.ident = id
        let me : Peer = Peer(userId: globalUserId)
        self.participants.append(me)
        self.lastKnownRecord = CKRecord(recordType: Goal.recordType, recordID: self.recordId)
    }
}


extension Goal {
    
    // cloudkit record data
    func fetchUserRecordID(completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        let container = Config.cloudContainer
        container.fetchUserRecordID { (recordID, error) in
            if let error = error {
                completion(.failure(error))
            } else if let recordID = recordID {
                completion(.success(recordID))
            }
        }
    }
}

extension Goal {
    
    /// The record type to use when saving a contact.
    static let recordType: CKRecord.RecordType = "Goal"
    var publicZoneId: CKRecordZone.ID { .default }
    
    private var recordId: CKRecord.ID { CKRecord.ID(recordName: self.ident, zoneID: self.publicZoneId) }
    
    func populateRecord(_ record: CKRecord) {
        
        record[.streakName] = self.name
        record[.type] = self.type.rawValue
        record[.enforceType] = self.enforceType.rawValue
        record[.password] = self.goalPasscode
        record[.timeLimitMinutes] = self.screenTimeMinutes
        record[.modifiedDate] = Date.now
        record[.target] = self.target
        do {
            try record.encode(self.participants, forKey: .peerlist)
        } catch(let error) {
            print("participant error encoding \(error)")
        }
        
    }
    
    func setLastKnownRecordIfNewer(_ otherRecord: CKRecord) {
        let localRecord = self.lastKnownRecord
        if let localDate = localRecord?.modificationDate {
            if let otherDate = otherRecord.modificationDate, localDate < otherDate {
                self.lastKnownRecord = otherRecord
                Logger.dataModel.info("Goal overwrote local record with server\(String(describing:otherRecord.recordChangeTag?.description))")
            } else {
                // The other record is older than the one we already have.
                Logger.dataModel.info("server goal record is older or equal, not setting. changetag\(String(describing:localRecord?.recordChangeTag?.description))")
            }
        } else {
            self.lastKnownRecord = otherRecord
            Logger.dataModel.info("Goal set server record \(String(describing:otherRecord.recordChangeTag?.description))")
        }
    }
    
    
    /// A deserialized version of `lastKnownRecordData`.
    /// Will return `nil` if there is no data or if the deserialization fails for some reason.
    var lastKnownRecord: CKRecord? {
        get {
            if let data = self.record.lastKnownRecordData {
                do {
                    let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
                    unarchiver.requiresSecureCoding = true
                    return CKRecord(coder: unarchiver)
                } catch {
                    // Why would this happen? What could go wrong? 🔥
                    Logger.dataModel.fault("Failed to decode local system fields record: \(error)")
                    return nil
                }
            } else {
                return nil
            }
        }
        
        set {
            if let newValue {
                let archiver = NSKeyedArchiver(requiringSecureCoding: true)
                newValue.encodeSystemFields(with: archiver)
                self.record.lastKnownRecordData = archiver.encodedData
            } else {
                self.record.lastKnownRecordData = nil
            }
        }
    }
    func updateUsers() {
        for index in self.participants.indices {
            self.participants[index].lastUpdate = Date.now
        }
    }
    func userBypassed() {
        for index in self.participants.indices {
            if self.participants[index].userId == MyUserDefaults.globalUserId {
                self.participants[index].appBypass()
            }
        }
        /*
         if var localUser = self.participants.firstIndex(where: {$0.userId == globalUserId}) {
         // user just bypassed app restrictions
         localUser.appBypass()
         }
         */
    }
    
    func getLocalUserValue() -> Double {
        let val: Double
        if let localUser = self.participants.first(where: {$0.userId == globalUserId}) {
            val = localUser.getTodaysValue()
        } else {
            val = 0
        }
        return val
    }
    
    func updateSharedDefaults()
    {
        let localUserVal = self.getLocalUserValue()
        let enforced_goal = enforced_goal(goal_name: self.type.description,
                                          goal: self.target,
                                          value: localUserVal,
                                          id: self.ident,
                                          updated: self.record.userModificationDate.timeIntervalSinceReferenceDate,
                                          type: self.type.rawValue)
        
        var enforced_goals = MyUserDefaults.load_enforced_goals()
        
        print("Updating shared defaults enforced count \(enforced_goals.goals.count)")
        
        if let index = enforced_goals.goals.firstIndex(where: {$0.id == self.ident}) {
            print("goal here \(enforced_goal.goal_name) \(enforced_goal.goal)")
            // this goal is already here
            enforced_goals.goals[index] = enforced_goal
            if (!self.enforceType.blocksApps) {
                // remove this one from enforced
                enforced_goals.goals.remove(at: index)
            }
        } else if (self.enforceType.blocksApps) {
            enforced_goals.goals.append(enforced_goal)
        }
        print("enforced count \(enforced_goals.goals.count)")
        MyUserDefaults.save_enforced_goals(enforced: enforced_goals)
    }
    
    func mergeFromServerRecord(_ record: CKRecord) {
        let userModificationDate: Date
        if let dateFromRecord = record[.modifiedDate] as? Date {
            userModificationDate = dateFromRecord
        } else {
            Logger.dataModel.info("No user modification date in contact record")
            userModificationDate = Date.distantPast
        }
        
        if userModificationDate > self.record.userModificationDate {
            Logger.dataModel.warning("USER Overrwriting Modification Date & Data!")
            self.record.userModificationDate = userModificationDate
            if let name = record[.streakName] as? String {
                self.name = name
            } else {
                Logger.dataModel.error("No name in goal record")
            }
            if let password = record[.password] as? String {
                self.goalPasscode = password
            } else {
                Logger.dataModel.error("No passcode in goal record")
            }
            if let timeLimit = record[.timeLimitMinutes] as? Int {
                self.screenTimeMinutes = timeLimit
            } else {
                Logger.dataModel.error("No screen time in goal record")
            }
            if let target = record[.target] as? Double {
                self.target = target
            } else {
                Logger.dataModel.error("No target in goal record")
            }
            if let type = record[.type] as? GoalType.RawValue {
                self._type = type
            } else {
                Logger.dataModel.error("No type in goal record")
            }
            if let type = record[.enforceType] as? EnforcementType.RawValue {
                self._enforceType = type
            } else {
                Logger.dataModel.error("No enforcement type in goal record")
            }
        } else {
            Logger.dataModel.info("Not overwriting data from older User record")
        }
        
        let test = try? record.decode(forKey: .peerlist) as [Peer]
        if let participants = test {
            for peerIndex in participants.indices {
                let peer = participants[peerIndex]
                let dr = peer.getTodaysData()
                let val = dr.value
                print("name:\(peer.name) val:\(val) vs local \(Int(self.getLocalUserValue())) update: \(peer.lastUpdate)")
                if let localIndex = self.participants.firstIndex(where: {$0.userId == peer.userId}) {
                    if peer.userId == globalUserId {
                        // this is me
                        // always trust local for now
                        print("trusting local instance over server one")
                    } else {
                        // update local instance with server
                        print("updating user \(peer.name)")
                        self.participants[localIndex] = peer
                    }
                } else {
                    print("adding user \(peer.name)")
                    self.participants.append(peer)
                }
            }
        } else {
            Logger.dataModel.error("Failed to decode user list")
        }
    }
}
