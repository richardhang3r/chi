//
//  FetchExistingGoal.swift
//  chi
//
//  Created by Richard Hanger on 6/4/24.
//

import SwiftUI
import CloudKit




struct RemoteGoalView: View {
    @StateObject private var viewModel = GoalViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.goals.isEmpty {
                    Text("nothing here")
                } else {
                    List(viewModel.goals) { goal in
                        NavigationLink {
                            PendingGoal(goal: goal)
                        } label: {
                            HStack
                            {
                                Image(systemName: goal.type.iconName)
                                Text("\(goal.type.title)")
                                Spacer()
                                Text("target: \(Int(goal.target))")
                                Spacer()
                                Text("users: \(goal.participants.count)")
                            }
                            .padding()
                        }
                        //.listRowBackground(Color(uiColor: UIColor.clear))
                        .clipShape(.capsule)
                        .shadow(radius: 10)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listStyle(.insetGrouped)
                    .listRowSpacing(15)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
            .background(Color.beige)
            .buttonStyle(.bordered)
            //.navigationTitle("Goals")
            .onAppear {
                viewModel.fetchGoals()
            }
        }
    }
}


struct FetchExistingGoal: View {
    @State private var recordName : String = ""
    @State private var record : CKRecord? = nil
    @State private var goal : Goal? = nil
    @State private var err : String? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            if let error = err {
                Text("\(error)")
                    .foregroundStyle(.red)
            }
            RemoteGoalView()
            
            Spacer()
            
            Text("search via code")
            TextField("goal id", text: $recordName) {
                print("commit")
                Task {
                    do {
                        record = try await CloudManager.fetchGoal(recordName: recordName)
                        print("got record \(record.debugDescription)")
                        goal = Goal(record: record!)
                        if let go = goal {
                            Router.shared.path.append(go)
                        }
                        err = nil
                    } catch (let error) {
                        err = error.localizedDescription
                    }
                }
                
            }
            .textFieldStyle(.roundedBorder)
            .padding()
            
            PasteButton(payloadType: String.self) { strings in
                guard let first = strings.first else { return }
                recordName = first
                Task {
                    do {
                        record = try await CloudManager.fetchGoal(recordName: recordName)
                        print("got record \(record.debugDescription)")
                        goal = Goal(record: record!)
                        if let go = goal {
                            Router.shared.path.append(go)
                        }
                        err = nil
                    } catch (let error) {
                        err = error.localizedDescription
                    }
                }
            }
            .padding()
            .buttonBorderShape(.capsule)
        }
        .padding()
        .navigationTitle("join existing goal")
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
        .navigationDestination(for: Goal.self) { goal in
            PendingGoal(goal: goal)
        }
    }
}

#Preview {
    let container = MainModelContainer().makeContainer()
    return FetchExistingGoal()
        .modelContainer(container)
}
