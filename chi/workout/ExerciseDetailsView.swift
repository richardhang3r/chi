//
//  ExerciseDetailsView.swift
//  FitCount
//
//  Created by QuickPose.ai on 22.05.2023.
//

import SwiftUI

import QuickPoseCore




struct Exercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let details: String
    let features: [QuickPose.Feature]
    // Add more properties as needed
}

class SessionConfig: ObservableObject {
    @Published var nReps : Int = 10
    @Published var nMinutes : Int = 2
    @Published var nSeconds : Int = 0
    @Published var useReps: Bool = false
    @Published var exercise: Exercise = Exercise(
        name: "Squats",
        details: "Bend your knees and lower your body.",
        features: [.fitness(.squats), .overlay(.wholeBody)])
    @Published var repsCompleted: Int = 0
    @Published var secondsSpent: Int = 0
}


struct TitleNavBarItem: View {
    let title: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ExerciseDetailsView: View {
    @EnvironmentObject var sessionConfig: SessionConfig
    @Environment(\.dismiss) private var dismiss
    
    let exercise: Exercise
    
    @State var selection = 1
    
    var body: some View {
        VStack {
            Text(exercise.name)
                .font(.title)
                .padding()
            Text(exercise.details)
                .font(.body)
                .padding()
            
            Button {
                dismiss()
            } label: {
                Text("begin")
                    .padding()
                    .cornerRadius(8)
            }
            .buttonStyle(.bordered)
            .clipShape(.ellipse)

            //            Spacer()
            
            //InstructionsView()
            
            
        }
    }
}
