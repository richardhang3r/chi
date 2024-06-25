//
//  WorkoutView.swift
//  FitCount
//
//  Created by QuickPose.ai on 22.05.2023.
//

import SwiftUI
import AVFoundation


struct WorkoutView: View {
    
    let exercise : Exercise
    @StateObject var sessionConfig = SessionConfig()
    
    @State var instructionsListed = true
    @State var cameraPermissionGranted = false
    
    var body: some View {
        GeometryReader { geometry in
            if cameraPermissionGranted {
                QuickPoseBasicView()
                    .environmentObject(sessionConfig)
            }
        }
        .sheet(isPresented: $instructionsListed) {
            ExerciseDetailsView(exercise: sessionConfig.exercise)
                .environmentObject(sessionConfig)
        }
        .onAppear {
            sessionConfig.exercise = exercise
            sessionConfig.useReps = false
            AVCaptureDevice.requestAccess(for: .video) { accessGranted in
                DispatchQueue.main.async {
                    self.cameraPermissionGranted = accessGranted
                }
            }
        }
    }
}
