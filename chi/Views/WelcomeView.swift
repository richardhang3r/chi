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
    @State var id : String = MyUserDefaults.globalUserId
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
            } else if (id.isEmpty) {
                Text("invalid icloud account")
                    .foregroundStyle(.red)
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
            print("welcome view on appear")
            //force set user id for now
            goal.fetchUserRecordID {result in
                DispatchQueue.main.async {
                    switch(result) {
                    case .success(let recordid):
                        print("found user id!!")
                        Config.forceSetUniqueUserId(id: recordid.recordName)
                        self.id = recordid.recordName
                        // reset goal with new user id
                        goal = Goal(userid: recordid.recordName)
                        break
                    case .failure(let error):
                        err = error.localizedDescription
                        break
                    }
                }
            }
            
            if !MyUserDefaults.globalUserId.isEmpty {
                print("shared user id: \(MyUserDefaults.globalUserId) local: \(globalUserId)")
                self.id = MyUserDefaults.globalUserId
            }
            
            print("user id: \(String(describing: goal.getLocalUser()?.userId))")
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
