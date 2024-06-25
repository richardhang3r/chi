//
//  PendingGoal.swift
//  chi
//
//  Created by Richard Hanger on 6/4/24.
//

import SwiftUI
@preconcurrency import FamilyControls

struct PendingGoal: View {
    let goal: Goal
    @State private var requestingPermission = false
    @State private var permissionGranted = false
    
    @State private var savingToCloud : Bool = false
    @State private var savedToCloud : Bool = false
    @State private var saveError : String = ""

    
    @Environment(\.modelContext) private var modelContext
    var body: some View {
        VStack {
            if savingToCloud {
                Text("joining...")
            }
            if !permissionGranted {
                Text("requesting permission...")
            }
            PeerView(goal: goal)
                .navigationTitle("pending goal")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                do {
                                    let me = Peer()
                                    goal.addUser(me)
                                    savingToCloud = true
                                    try await CloudManager.saveToCloud(goal: goal)
                                    goal.setup()
                                    goal.manualUpdate()
                                    modelContext.insert(goal)
                                    Router.shared.popToRoot()
                                } catch (let error) {
                                    print("cm error \(error)")
                                    saveError = error.localizedDescription
                                }
                                savingToCloud = false
                            }
                        } label: {
                            Text("accept")
                        }
                        .disabled(!permissionGranted)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
        .onAppear {
            if goal.type.supportHealthKit {
                requestingPermission = true
                print("\(goal.type.title) supports healthkit")
                HealthData.requestHealthDataAccessIfNeeded(dataTypes: [goal.type.healthIdentifier.rawValue]) {success in
                    DispatchQueue.main.async {
                        requestingPermission = false
                        permissionGranted = success
                        print("permission granted to \(success) \(permissionGranted)")
                    }
                }
            } else {
                requestingPermission = false
                permissionGranted = true
            }
            print("pending goal on appear \(requestingPermission)")
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                } catch {
                    print("Failed to enroll Aniyah with error: \(error)")
                }
            }
        }
    }
}

#Preview {
    PendingGoal(goal: Goal())
}
