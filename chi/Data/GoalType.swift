//
//  GoalType.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import Foundation
import HealthKit

enum GoalStatus {
    case passed
    case failed
    case pending
    case absent
}

enum GoalType: Int, CaseIterable {
    // simply lose streak if device activity time exceeds limit before accomplishing goal
    case squat
    case steps
    case heartrate
    // block apps until goal is accomplished
    // block apps if device activity times exceeds limit before accomplishing goal
    case pushup
    case jumpingjack
    case plank
    case daylightTime
    case meditate
    case walkingSpeed
    case sleep
    case distance

    var isSupported : Bool {
        switch self {
        case .squat, .steps, .pushup:
            return true
        default:
            return false
        }
    }

}


extension GoalType {
    var descriptionPlural: String {
        switch self {
        case .steps:
            return "steps"
        case .heartrate:
            return "heart rate"
        case .squat:
            return "squats"
        case .pushup:
            return "pushups"
        case .jumpingjack:
            return "jumping jacks"
        case .plank:
            return "planks"
        default:
            return "unknown"
        }
    }
    
    var description: String {
        switch self {
        case .steps:
            return "step"
        case .heartrate:
            return "heart rate"
        case .squat:
            return "squat"
        case .pushup:
            return "pushup"
        case .jumpingjack:
            return "jumping jack"
        case .plank:
            return "plank"
        default:
            return "unknown"
        }
    }
    
    
    var defaultValue : Double
    {
        switch self {
        case .steps:
            return 500
        case .meditate:
            return 3
        case .heartrate:
            return 120
        case .squat,.plank,.pushup,.jumpingjack:
            return 10
        case .daylightTime:
            return 60
        default:
            return 0
        }
    }
    
    
    var maxValue : Int
    {
        switch self {
        case .steps:
            return 20000
        case .heartrate:
            return 200
        case .sleep:
            return 10
        case .squat,.plank,.pushup,.jumpingjack,.meditate:
            return 60
        case .daylightTime:
            return 300
        default:
            return 0
        }
    }
    
    var title : String
    {
        switch self {
        case .steps:
            return "step count"
        case .heartrate:
            return "max heart rate"
        case .sleep:
            return "sleep hours"
        case .daylightTime:
            return "time in daylight"
            /*
        case .walkingSpeed:
            return "Walking Speed"
        case .v02Max:
            return "V02 Max"
        case .bodyMass:
            return "Weight"
             */
        case .plank:
            return "plank"
        case .squat:
            return "squats"
        case .pushup:
            return "pushups"
        case .meditate:
            return "meditate"
        case .jumpingjack:
            return "jumping jacks"
        default:
            return "Custom"
        }
    }
    
    var increment : Int
    {
        switch self {
        case .steps:
            return 100
        case .heartrate:
            return 5
        case .squat,.plank,.pushup,.jumpingjack,.meditate:
            return 1
        case .sleep:
            return 1
        case .daylightTime:
            return 5
        default:
            return 10
        }
    }
    
    var minValue : Int
    {
        switch self {
        case .steps:
            return 100
        case .squat,.plank,.pushup,.jumpingjack,.meditate:
            return 3
        case .heartrate:
            return 60
        case .sleep:
            return 3
        case .daylightTime:
            return 30
        default:
            return 0
        }
    }
    
    var supportHealthKit : Bool {
        switch self {
        case .squat,.plank,.pushup,.jumpingjack,.meditate:
            return false
        default:
            return true
        }
    }
    
    var isSystemIcon : Bool {
        switch self {
        default:
            return true
        }
    }
    
    var healthIdentifier :  HKQuantityTypeIdentifier
    {
        switch self {
        case .steps:
            return HKQuantityTypeIdentifier.stepCount
        case .heartrate:
            return HKQuantityTypeIdentifier.heartRate
        case .daylightTime:
            return HKQuantityTypeIdentifier.timeInDaylight
            // sleep data
            /*
             case .v02Max:
                 return HKQuantityTypeIdentifier.vo2Max
             case .bodyMass:
                 return HKQuantityTypeIdentifier.bodyMass
            HKCategoryValueSleepAnalysis.awake
            HKCategoryValueSleepAnalysis.asleepDeep
            HKCategoryValueSleepAnalysis.inBed
            HKCategoryValueSleepAnalysis.asleepCore
            HKCategoryValueSleepAnalysis.asleepUnspecified
            return HKQuantityTypeIdentifier.height
            return HKQuantityTypeIdentifier.bodyFatPercentage
            return HKQuantityTypeIdentifier.appleExerciseTime
            return HKQuantityTypeIdentifier.cyclingSpeed
            return HKQuantityTypeIdentifier.walkingSpeed
             */
            /*
            return HKQuantityTypeIdentifier.appleExerciseTime
             */
        default:
            // TODO: fix this
            return HKQuantityTypeIdentifier.underwaterDepth
        }
    }
    
    var iconName : String {
        switch self {
        case .meditate:
            "figure.mind.and.body"
        case .squat:
            "figure.cross.training"
        case .pushup:
            "figure.arms.open"
        case .jumpingjack:
            "figure.mixed.cardio"
        case .plank:
            "figure.fall"
        case .steps:
            "figure.walk"
        case .heartrate:
            "heart.fill"
        case .daylightTime:
            "sun.max.fill"
        case .sleep:
            "bed.double.fill"
        case .walkingSpeed:
            "figure.walk.motion"
        default:
            "questionmark"
        }
    }
}

