//
//  CloudManager.swift
//  chi
//
//  Created by Richard Hanger on 6/4/24.
//

import Foundation
import CloudKit
import os.log


/*
 public enum CKErrorCode : Int {
   case InternalError /* CloudKit.framework encountered an error.  This is a non-recoverable error. */
   case PartialFailure /* Some items failed, but the operation succeeded overall */
   case NetworkUnavailable /* Network not available */
   case NetworkFailure /* Network error (available but CFNetwork gave us an error) */
   case BadContainer /* Un-provisioned or unauthorized container. Try provisioning the container before retrying the operation. */
   case ServiceUnavailable /* Service unavailable */
   case RequestRateLimited /* Client is being rate limited */
   case MissingEntitlement /* Missing entitlement */
   case NotAuthenticated /* Not authenticated (writing without being logged in, no user record) */
   case PermissionFailure /* Access failure (save or fetch) */
   case UnknownItem /* Record does not exist */
   case InvalidArguments /* Bad client request (bad record graph, malformed predicate) */
   case ResultsTruncated /* Query results were truncated by the server */
   case ServerRecordChanged /* The record was rejected because the version on the server was different */
   case ServerRejectedRequest /* The server rejected this request.  This is a non-recoverable error */
   case AssetFileNotFound /* Asset file was not found */
   case AssetFileModified /* Asset file content was modified while being saved */
   case IncompatibleVersion /* App version is less than the minimum allowed version */
   case ConstraintViolation /* The server rejected the request because there was a conflict with a unique field. */
   case OperationCancelled /* A CKOperation was explicitly cancelled */
   case ChangeTokenExpired /* The previousServerChangeToken value is too old and the client must re-sync from scratch */
   case BatchRequestFailed /* One of the items in this batch operation failed in a zone with atomic updates, so the entire batch was rejected. */
   case ZoneBusy /* The server is too busy to handle this zone operation. Try the operation again in a few seconds. */
   case BadDatabase /* Operation could not be completed on the given database. Likely caused by attempting to modify zones in the public database. */
   case QuotaExceeded /* Saving a record would exceed quota */
   case ZoneNotFound /* The specified zone does not exist on the server */
   case LimitExceeded /* The request to the server was too large. Retry this request as a smaller batch. */
   case UserDeletedZone /* The user deleted this zone through the settings UI. Your client should either remove its local data or prompt the user before attempting to re-upload any data to this zone. */
 }
 */


enum CloudKitState : Equatable {
    case idle
    case busy
    case success([Goal])
    case modifyDone([CKRecord], [CKRecord.ID])
    case error(String)
}

class CloudKitManager: ObservableObject {
    
    @Published var errorMessage: String?
    @Published var state: CloudKitState = .idle
    private var database = Config.cloudContainer.publicCloudDatabase
    
    func removeFromGoal(userId: String, recordId: CKRecord.ID) async {
        do {
            self.state = .busy
            try await _removeFromGoal(userId: userId, recordId: recordId)
        } catch {
            self.state = .error(mapCloudKitError(error))
        }
    }
    
    func removeSelfFromGoal(userId: String, recordId: CKRecord.ID) {
        print("fetching goals")
        self.state = .busy
        let operation = CKFetchRecordsOperation(recordIDs: [recordId])
        operation.perRecordResultBlock = {
            (recordID: CKRecord.ID, recordResult: Result<CKRecord, Error>) in
            switch recordResult {
            case .success(let serverRecord):
                // Handle the changed record here
                print("Record \(recordID.recordName) found \(serverRecord)")
                self._deleteGoalAsync(serverRecord: serverRecord, userId: userId)
            case .failure(let error):
                // Handle the error
                print("Error changing record \(recordID.recordName): \(error)")
                DispatchQueue.main.async { [weak self] in
                    if let self = self {
                        self.state = .error(self.mapCloudKitError(error))
                    }
                }
            }
            return
        }
        
        database.add(operation)
    }
    
    func updateUserAsync(me: Peer, recordId: CKRecord.ID) {
        self.state = .busy
        let operation = CKFetchRecordsOperation(recordIDs: [recordId])
        operation.perRecordResultBlock = {
            (recordID: CKRecord.ID, recordResult: Result<CKRecord, Error>) in
            switch recordResult {
            case .success(let serverRecord):
                // Handle the changed record here
                do {
                    print("Record \(recordID.recordName) found \(serverRecord)")
                    var participants = try serverRecord.decode(forKey: .peerlist) as [Peer]
                    if let serverIndex = participants.firstIndex(where: {me.userId == $0.userId}) {
                        // remove server understanding
                        print("replacing server me with local me")
                        participants[serverIndex] = me
                    } else {
                        print("no record of me in participant list.  adding")
                        participants.append(me)
                    }
                    // write new list back to record
                    try serverRecord.encode(participants, forKey: .peerlist)
                    self._modifyRecordsAsync(saveRecords: [serverRecord])
                } catch {
                    print("\(error.localizedDescription)")
                }
                
            case .failure(let error):
                // Handle the error
                print("Error changing record \(recordID.recordName): \(error)")
                DispatchQueue.main.async { [weak self] in
                    if let self = self {
                        self.state = .error(self.mapCloudKitError(error))
                    }
                }
            }
            return
        }
        database.add(operation)
        /*
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
         */
    }

    
    
    func fetchGoals() {
        print("fetching goals")
        self.state = .busy
        let query = CKQuery(recordType: "Goal", predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        var fetchedGoals: [Goal] = []
        operation.recordMatchedBlock = { reco, res in
            print("found reocrd")
            switch res {
            case .success(let record):
                if let goal = Goal(record: record) {
                    fetchedGoals.append(goal)
                } else {
                    Logger.database.error("invalid record \(record.debugDescription)")
                }
                break;
            case .failure(let error):
                Logger.database.error("query failure: \(error.localizedDescription)")
                self.state = .error(self.mapCloudKitError(error))
                break;
            }
        }
        operation.queryResultBlock = { res in
            switch res {
            case .success(let cursor):
                print("success cursor \(cursor.debugDescription)")
                self.state = .success(fetchedGoals)
                break;
            case .failure(let error):
                self.state = .error(self.mapCloudKitError(error))
                print("error! \(error.localizedDescription)")
                break;
            }
        }
        
        database.add(operation)
    }
    
    private func _modifyRecordsAsync(saveRecords: [CKRecord] = [], deleteIds: [CKRecord.ID] = []) {
        let operation = CKModifyRecordsOperation(recordsToSave: saveRecords, recordIDsToDelete: deleteIds)
        //operation.isAtomic = false
        var savedRecords: [CKRecord] = []
        var deletedRecordIds: [CKRecord.ID] = []
        operation.perRecordSaveBlock = {
            (recordID: CKRecord.ID, saveResult: Result<CKRecord, Error>) in
            switch saveResult {
            case .success(let record):
                // Handle the changed record here
                savedRecords.append(record)
                break;
            case .failure(let error):
                print("save err: \(self.mapCloudKitError(error))")
                break;
            }
        }
        operation.perRecordDeleteBlock = {
            (recordID: CKRecord.ID, saveResult: Result<Void, Error>) in
            print("result \(recordID) \(saveResult)")
            switch saveResult {
            case .success:
                // Handle the changed record here
                deletedRecordIds.append(recordID)
                break;
            case .failure(let error):
                // Handle the error
                print("delete err: \(self.mapCloudKitError(error))")
                break;
            }
            return
        }
        
        operation.modifyRecordsResultBlock = {
            (_ operationResult: Result<Void, Error>) in
            print("done \(operationResult)")
            switch operationResult {
            case .success:
                DispatchQueue.main.async { [weak self] in
                    if let self = self {
                        self.state = .modifyDone(savedRecords, deletedRecordIds)
                    }
                }
                break;
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    if let self = self {
                        self.state = .error(self.mapCloudKitError(error))
                    }
                }
                break;
            }
            return
        }
        
        database.add(operation)
    }
    
    private func _deleteGoalAsync(serverRecord: CKRecord, userId: String) {
        guard let goal = Goal(record: serverRecord) else {
            print("invalid server recrd \(serverRecord.debugDescription)")
            return
        }
        goal.participants.removeAll(where: {$0.userId == userId})
        if goal.participants.isEmpty {
            print("no participants left, deleting")
            _modifyRecordsAsync(deleteIds: [serverRecord.recordID])
        } else {
            // repopulate server record new participant list
            goal.populateRecord(serverRecord)
            _modifyRecordsAsync(saveRecords: [serverRecord])
        }
    }
    private func deleteFromCloud(record: CKRecord) async throws {
        
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

    

    private func _removeFromGoal(userId: String, recordId: CKRecord.ID) async throws {
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
                self.state = .success([goal])
            case .failure(let error):
                print("error \(error) ")
                self.state = .error(mapCloudKitError(error))
            }
        }
    }
    
    private func mapCloudKitError(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return "An unknown error occurred."
        }
        
        switch ckError.code {
        case .internalError:
            return "internal error occurred within CloudKit."
        case .partialFailure:
            return "partial failure occurred. Some items were not processed."
        case .networkUnavailable:
            return "network is unavailable."
        case .networkFailure:
            return "network failure occurred."
        case .badContainer:
            return "bad container identifier."
        case .serviceUnavailable:
            return "cloudKit service is currently unavailable."
        case .requestRateLimited:
            return "Request rate limit exceeded."
        case .missingEntitlement:
            return "Missing required entitlement."
        case .notAuthenticated:
            return "User is not authenticated."
        case .permissionFailure:
            return "Permission failure occurred."
        case .unknownItem:
            return "unknown item."
        case .invalidArguments:
            return "invalid arguments were provided."
        case .resultsTruncated:
            return "results were truncated."
        case .serverRecordChanged:
            return "record was changed on the server."
        case .serverRejectedRequest:
            return "rerver rejected the request."
        case .assetFileNotFound:
            return "rsset file was not found."
        case .assetFileModified:
            return "asset file was modified."
        case .incompatibleVersion:
            return "incompatible version."
        case .constraintViolation:
            return "constraint violation."
        case .operationCancelled:
            return "operation was cancelled."
        case .changeTokenExpired:
            return "change token expired."
        case .batchRequestFailed:
            return "batch request failed."
        case .zoneBusy:
            return "zone is busy."
        case .zoneNotFound:
            return "zone was not found."
        case .limitExceeded:
            return "limit exceeded."
        case .userDeletedZone:
            return "user deleted the zone."
        case .tooManyParticipants:
            return "too many participants."
        case .alreadyShared:
            return "item is already shared."
        case .referenceViolation:
            return "reference violation."
        case .managedAccountRestricted:
            return "managed account restricted."
        case .participantMayNeedVerification:
            return "participant may need verification."
        case .serverResponseLost:
            return "server response lost."
        case .assetNotAvailable:
            return "asset not available."
        default:
            return "unknown: \(ckError.localizedDescription)"
        }
    }
}

class CloudManager {
    
    static func mapCloudKitError(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return "An unknown error occurred."
        }
        
        switch ckError.code {
        case .internalError:
            return "Internal error occurred within CloudKit."
        case .partialFailure:
            return "Partial failure occurred. Some items were not processed."
        case .networkUnavailable:
            return "Network is unavailable."
        case .networkFailure:
            return "Network failure occurred."
        case .badContainer:
            return "Bad container identifier."
        case .serviceUnavailable:
            return "CloudKit service is currently unavailable."
        case .requestRateLimited:
            return "Request rate limit exceeded."
        case .missingEntitlement:
            return "Missing required entitlement."
        case .notAuthenticated:
            return "User is not authenticated."
        case .permissionFailure:
            return "Permission failure occurred."
        case .unknownItem:
            return "Unknown item."
        case .invalidArguments:
            return "Invalid arguments were provided."
        case .resultsTruncated:
            return "Results were truncated."
        case .serverRecordChanged:
            return "Record was changed on the server."
        case .serverRejectedRequest:
            return "Server rejected the request."
        case .assetFileNotFound:
            return "Asset file was not found."
        case .assetFileModified:
            return "Asset file was modified."
        case .incompatibleVersion:
            return "Incompatible version."
        case .constraintViolation:
            return "Constraint violation."
        case .operationCancelled:
            return "Operation was cancelled."
        case .changeTokenExpired:
            return "Change token expired."
        case .batchRequestFailed:
            return "Batch request failed."
        case .zoneBusy:
            return "Zone is busy."
        case .zoneNotFound:
            return "Zone was not found."
        case .limitExceeded:
            return "Limit exceeded."
        case .userDeletedZone:
            return "User deleted the zone."
        case .tooManyParticipants:
            return "Too many participants."
        case .alreadyShared:
            return "Item is already shared."
        case .referenceViolation:
            return "Reference violation."
        case .managedAccountRestricted:
            return "Managed account restricted."
        case .participantMayNeedVerification:
            return "Participant may need verification."
        case .serverResponseLost:
            return "Server response lost."
        case .assetNotAvailable:
            return "Asset not available."
        default:
            return "unknown: \(ckError.localizedDescription)"
        }
    }
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
