//
//  CloudManager.swift
//  chi
//
//  Created by Richard Hanger on 6/4/24.
//

import Foundation
import CloudKit
import os.log



class CloudManager {
    
    static func fetchGoal(recordName: String) async throws -> CKRecord {
        let container = Config.cloudContainer
        // using public database only
        let database : CKDatabase = container.publicCloudDatabase
        // get record
        let goal = Goal(id: recordName)
        let localRecord = goal.lastKnownRecord!
        do {
            return try await database.record(for: localRecord.recordID)
        } catch(let error) {
            print("could not fetch server record \(error)")
            throw error
        }
    }

    static func deleteFromCloud(record: CKRecord) async throws {
        let container = Config.cloudContainer
        // using public database only
        let database : CKDatabase = container.publicCloudDatabase
        // send back up
        let modifyResults = try await database.modifyRecords(saving: [], deleting: [record.recordID])
        
        let deleteResults = modifyResults.deleteResults
        for key in deleteResults {
            switch(key.value) {
            case .success():
                print("delete success")
            case .failure(let error):
                print("error \(error) ")
                throw error
            }
        }
    }
    
    static func removeFromGoal(userId: String, recordId: CKRecord.ID) async throws {
        let container = Config.cloudContainer
        // using public database only
        let database : CKDatabase = container.publicCloudDatabase
        // get record
        let serverRecord : CKRecord = try await database.record(for: recordId)
        guard let goal = Goal(record: serverRecord) else {
            print("invalid server recrd \(serverRecord.debugDescription)")
            return
        }
        
        goal.participants.removeAll(where: {$0.userId == userId})
        
        if goal.participants.isEmpty {
            print("no participants left, deleting")
            try await deleteFromCloud(record: serverRecord)
            return
        }
        
        // repopulate server record new participant list
        goal.populateRecord(serverRecord)
        
        // send back up
        let modifyResults = try await database.modifyRecords(saving: [serverRecord], deleting: [])

        // verify results
        let saveResults = modifyResults.saveResults
        for key in saveResults {
            switch(key.value) {
            case .success(let record):
                print("success \(record.description)")
            case .failure(let error):
                print("error \(error) ")
                throw error
            }
        }
    }
    
    
    static func updateUser(me: Peer, recordId: CKRecord.ID) async throws {
        
        
        print("updating user of server record with id \(recordId.debugDescription)")
        
        let container = Config.cloudContainer
        // using public database only
        let database : CKDatabase = container.publicCloudDatabase
        let serverRecord : CKRecord
        do {
            serverRecord = try await database.record(for: recordId)
        } catch(let error) {
            print("could not fetch server record \(error)")
            throw error
        }
        
        var participants = try serverRecord.decode(forKey: .peerlist) as [Peer]
        
        if let serverIndex = participants.firstIndex(where: {globalUserId == $0.userId}) {
            // remove server understanding
            print("replacing server me with local me")
            participants[serverIndex] = me
        } else {
            print("no record of me in participant list.  adding")
            participants.append(me)
        }
        
        // write new list back to record
        try serverRecord.encode(participants, forKey: .peerlist)
        
        serverRecord[.modifiedDate] = Date.now

        // send back up
        let modifyResults = try await database.modifyRecords(saving: [serverRecord], deleting: [])

        // verify results
        let saveResults = modifyResults.saveResults
        for key in saveResults {
            switch(key.value) {
            case .success(let record):
                print("success \(record.description)")
            case .failure(let error):
                print("error \(error) ")
                throw error
            }
        }

    }
    
    static func saveToCloud(goal: Goal) async throws {
        
        
        let container = Config.cloudContainer
        // using public database only
        let database : CKDatabase = container.publicCloudDatabase
        // get record
        let localRecord = goal.lastKnownRecord!
        let serverRecord : CKRecord
        do {
            print("fetching server goal record with id \(localRecord.debugDescription)")
            serverRecord = try await database.record(for: localRecord.recordID)
        } catch(let error) {
            print("could not fetch server record \(error)")
            serverRecord = localRecord
        }
        
        // merge server record with local record
        goal.mergeFromServerRecord(serverRecord)
        
        // repopulate server record with merged data
        goal.populateRecord(serverRecord)
        
        if goal.participants.isEmpty {
            print("no participants left, deleting")
            try await deleteFromCloud(record: serverRecord)
            return
        }
        
        // send back up
        let modifyResults = try await database.modifyRecords(saving: [serverRecord], deleting: [])

        // verify results
        let saveResults = modifyResults.saveResults
        for key in saveResults {
            switch(key.value) {
            case .success(let record):
                print("success \(record.description)")
            case .failure(let error):
                print("error \(error) ")
                throw error
            }
        }

        // need to create share here
        /*
        let recordId = goal.record.lastKnownRecord!.recordID
        
        let record = try await database.record(for: recordId)
        
        goal.populateRecord(record)
        
       // try await database.record(for: shareId) as! CKShare
        //let share = CKShare(rootRecord: record)
        //share[CKShare.SystemFieldKey.title] = "Streak: \(streak.type)"
        //share.publicPermission = .readWrite
        //print("got goal record changetag: \(String(describing: record.recordChangeTag))")
        
        let child : Peer = streak.getLocalUser()!
        let childId : CKRecord.ID = child.record.lastKnownRecord!.recordID
        let childRecord = try await database.record(for: childId)
        child.populateRecord(childRecord)
        childRecord.parent = CKRecord.Reference(record: record, action: .none)
        print("got child record ready! \(String(describing: childRecord.recordChangeTag))")
        
        print("saving share to server")
        let modifyResults = try await database.modifyRecords(saving: [record, childRecord,share], deleting: [])
        print("got results")
        let saveResults = modifyResults.saveResults
        
        for key in saveResults {
            switch(key.value) {
            case .success(let record):
                if (key.key == share.recordID) {
                    print("returing share")
                    return record as! CKShare
                } else {
                    print("successful save \(record)")
                }
            case .failure(let error):
                print("error \(error) ")
            }
        }
         */
    }
}
