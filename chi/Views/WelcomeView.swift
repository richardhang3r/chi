//
//  WelcomeView.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

import SwiftUI
import CloudKit

struct WelcomeView: View {
    @State var goal: Goal = Goal()
    @State var id: CKRecord.ID? = nil
    @State var err: String? = nil
    @State var commited: Bool = currentUserName != nil
    @State private var username = currentUserName ?? ""
    
    var body: some View {
        VStack {
            Image(systemName: "laurel.trailing")
                .padding()
            Text("chi")
                .font(.title)
            Text("ta chi tackle goals")
                .font(.caption)
            Spacer()
            if commited == false {
                TextField("enter username here", text: $username, onCommit: {
                    // Save the username or perform any other action here
                    commited = true
                    UserDefaults.standard.setValue(username, forKey: "UserName")
                    // reset goal with new username
                    goal = Goal()
                })
                .textFieldStyle(.roundedBorder)
                .padding()
            } else {
                NavigationLink(value: 13) {
                    Text("join existing")
                        .padding()
                }
                .buttonStyle(.bordered)
                NavigationLink(value: 1) {
                    Text("create new")
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Image(systemName: "laurel.trailing")
                .padding()
            if let error = err {
                Text("\(error)")
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
        .onAppear {
            if MyUserDefaults.globalUserId.isEmpty {
                goal.fetchUserRecordID {result in
                    switch(result) {
                    case .success(let recordid):
                        id = recordid
                        Config.forceSetUniqueUserId(id: recordid.recordName)
                        break
                    case .failure(let error):
                        err = error.localizedDescription
                        break
                    }
                    goal = Goal()
                    self.id = id
                }
            }
        }
        .navigationDestination(for: Int.self) { num in
            switch(num) {
            case 1:
                SelectGoalType(goal: $goal)
            case 2:
                ScreentimeAppView()
            case 3:
                GoalPasscodeView(goal: $goal)
            case 4:
                GoalSummaryPage(goal: goal)
            case 13:
                FetchExistingGoal()
            default:
                Text("done")
            }
        }
    }
}

#Preview {
    let container = MainModelContainer().makeContainer()
    return WelcomeView()
        .modelContainer(container)
}
