//
//  ServerRecordData.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import Foundation
import CloudKit
import os.log

extension CKRecord.FieldKey {
    
    static let currentStreak = "currentStreak"
    static let bestStreak = "bestStreak"
    static let modifiedDate = "last_modified"
    static let createdDate = "created_date"
    static let startTime = "start_time"
    static let userName = "name"
    static let streakName = "title"
    static let type = "type"
    static let id = "id"
    static let target = "target"
    static let peerlist = "participantlist"
    static let streakId = "streak_id"
    static let userId = "user_id"
    static let blockApps = "blockApps"
    static let valueHistory = "value_history"
    static let enforceType = "enforceType"
    static let timeLimitMinutes = "timeLimitMinutes"
    static let password = "pin"
    static let isActive = "active"
}

private let encoder: JSONEncoder = .init()
private let decoder: JSONDecoder = .init()

extension CKRecord {
    func decode<T>(forKey key: FieldKey) throws -> T where T: Decodable {
        guard let data = self[key] as? Data else {
            throw CocoaError(.coderValueNotFound)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    func encode<T>(_ encodable: T, forKey key: FieldKey) throws where T: Encodable {
        self[key] = try encoder.encode(encodable)
    }
}

/// The main model object for the app.
struct ServerRecordData : Codable {
    
    /// The date this contact was last modified in the UI.
    /// Used for conflict resolution.
    var dateCreated: Date = Date.now
    /// The date this contact was last modified in the UI.
    /// Used for conflict resolution.
    var userModificationDate: Date = Date.distantPast
    
    /// The encoded `CKRecord` system fields last known to be on the server.
    var lastKnownRecordData: Data?
    
    /// The encoded `CKShare` system fields last known to be on the server.
    var lastKnownShareData: Data?
}
