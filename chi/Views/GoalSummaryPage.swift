//
//  GoalSummaryPage.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import SwiftUI

struct GoalSummaryPage: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var goal: Goal
    var displayButton: Bool = true
    
    @State var savingToCloud : Bool = false
    @State var savedToCloud : Bool = false
    @State var saveError : String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if savingToCloud {
                Text("saving...")
            }
            if savedToCloud {
                Text("saved")
            }
            if !saveError.isEmpty {
                Text("\(saveError)")
                    .foregroundStyle(.red)
            }
            Spacer()
            Text("Goal Summary")
                .font(.headline)
                .padding(.bottom, 10)
            Group {
                let pinNeeded = !goal.goalPasscode.isEmpty
                let pinText = pinNeeded ? "yes" : "no"
                infoRow(label: "Name", value: goal.name, icon: "text.book.closed")
                infoRow(label: "Type", value: goal.type.title, icon:  goal.type.iconName)
                infoRow(label: "Target", value: String(Int(goal.target)), icon: "target")
                infoRow(label: "Pin", value: pinText, icon:  pinNeeded ? "lock.fill" : "lock.open.fill")
                infoRow(label: "Enforcement", value: goal.enforceType.title, icon:  "hand.raised.fill")
            }
            if (!goal.participants.isEmpty) {
                Text("Users: \(goal.participants.count)")
                    .font(.headline)
                    .padding(.top,10)
                    .padding(.bottom,10)
                Group {
                    ForEach(goal.participants) { peer in
                        infoRow(label: "Name", value: peer.name, icon: "person")
                    }
                }
            }
            if (displayButton) {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        if savedToCloud == false {
                            Task {
                                do {
                                    savingToCloud = true
                                    try await CloudManager.saveToCloud(goal: goal)
                                    goal.setup()
                                    modelContext.insert(goal)
                                } catch (let error) {
                                    print("cm error \(error)")
                                    saveError = error.localizedDescription
                                }
                                savingToCloud = false
                            }
                        } else {
                        }
                    } label: {
                        Text("create")
                            .bold()
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                Spacer()
            }
        }
        .padding()
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
    }
    
    

}

#Preview {
    let container = MainModelContainer().makeContainer()
    return GoalSummaryPage(goal: Goal())
        .modelContainer(container)
}
