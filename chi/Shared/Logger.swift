//
//  Logger.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import Foundation
import os.log

extension Logger {
    
    static let loggingSubsystem: String = "com.apple.samples.cloudkit.SyncEngine"
    
    static let healthKit = Logger(subsystem: Self.loggingSubsystem, category: "healthKit")
    static let ui = Logger(subsystem: Self.loggingSubsystem, category: "UI")
    static let database = Logger(subsystem: Self.loggingSubsystem, category: "Database")
    static let dataModel = Logger(subsystem: Self.loggingSubsystem, category: "DataModel")
}
