//
//  GoalWorkoutExtension.swift
//  chi
//
//  Created by Richard Hanger on 6/20/24.
//

import Foundation


extension GoalType {
    var exercise : Exercise? {
        switch self {
        case .squat:
            return Exercise(
                name: "Squats",
                details: "Bend your knees and lower your body.",
                features: [.fitness(.squats), .overlay(.wholeBody)]
            )
        case .pushup:
            return Exercise(
                name: "Pushups",
                details: "Do a pushup.",
                features: [.fitness(.pushUps), .overlay(.wholeBody)]
            )
        default:
            return nil
        }
    }
}
