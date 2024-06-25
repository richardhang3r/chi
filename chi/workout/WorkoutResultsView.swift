//
//  WorkoutResults.swift
//  FitCount
//
//  Created by QuickPose.ai on 25.05.2023.
//

import SwiftUI
import SwiftData

struct WorkoutResultsView: View {
    let sessionData: SessionData
    
    @EnvironmentObject var sessionConfig: SessionConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView{
            VStack(spacing: 20) {
                Spacer()
                Text("results")
                    .font(.largeTitle)
                    .padding(.top, 50)

                Text("reps recorded: \(sessionData.count)")
                    .font(.title2)
                    .padding(.top, 50)
                    .padding(.bottom, 20)
                
                Text("time elapsed: \(sessionData.seconds) seconds")
                    .font(.title2)
                    .padding(.bottom, 40)

                Button(action: {
                    dismiss()
                }) {
                    Text("exit")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                }
                .padding()
                .buttonStyle(PlainButtonStyle()) // Remove button style highlighting
                
                Spacer()
            }
            .onAppear {
                sessionConfig.repsCompleted = sessionData.count
                sessionConfig.secondsSpent = sessionData.seconds
                if let goals = try? modelContext.fetch(FetchDescriptor<Goal>()) {
                    for goal in goals {
                        _ = goal.updateData(val: Double(sessionData.count), date: Date.now)
                        Task {
                            do {
                                try await CloudManager.saveToCloud(goal:goal)
                            } catch (let error) {
                                print("failed to save to cloud \(error)")
                            }
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .padding()
        }
    }
}

