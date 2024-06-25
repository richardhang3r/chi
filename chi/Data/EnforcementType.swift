//
//  EnforcementType.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import Foundation

enum EnforcementType: Int, CaseIterable {
    case nothing
    // block apps until goal is accomplished
    case blockAppsFirst
    // simply lose streak if device activity time exceeds limit before accomplishing goal
    case maxTimeNoBlock
    // block apps if device activity times exceeds limit before accomplishing goal
    case blockAppsAfterTime
    case ugh

    var isSupported : Bool {
        switch self {
        case .maxTimeNoBlock, .blockAppsFirst, .blockAppsAfterTime, .nothing:
            return true
        default:
            return false
        }
    }
    
    var blocksApps : Bool {
        switch self {
        case .blockAppsFirst, .blockAppsAfterTime:
            return true
        default:
            return false
        }
    }

}

extension EnforcementType {
    
    var title: String {
        switch self {
        case .nothing:
            return "none"
        case .maxTimeNoBlock:
            return "screentime limit"
        case .blockAppsFirst:
            return "block apps before goal"
        case .blockAppsAfterTime:
            return "screentime limit + block apps"
        default:
            return "unknown"
        }
    }
    
    var description: String {
        switch self {
        case .maxTimeNoBlock:
            return "accomplish goal before exceeding allotted screentime"
        case .blockAppsFirst:
            return "chosen apps are blocked until goal is complete"
        case .blockAppsAfterTime:
            return "block apps if screentime is exceeded before goal is completed"
        case .nothing:
            return "keep track of streak"
        default:
            return "unknown"
        }
    }
    
    
    var selectDescription: String {
        switch self {
        case .maxTimeNoBlock:
            return "select screentime limit"
        case .blockAppsFirst, .blockAppsAfterTime:
            return "select apps to block"
        default:
            return "unknown"
        }
    }
}
