//
//  RootView.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

import SwiftUI
import SwiftData
import CloudKit
import os.log

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var router: Router = Router.shared
    @Environment(\.scenePhase) var scenePhase

    @Query private var goals: [Goal]
    init() {
        print("init root")
    }
    
    var body: some View {
        VStack {
            if goals.isEmpty {
                NavigationStack {
                    WelcomeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
                        .background(Color.beige)
                }
            } else {
                NavigationStack(path: $router.path) {
                    HomeViewRoot(goalid: goals.first!.ident)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    for goal in goals {
                        handleScenePhaseChange(newPhase, goal: goal)
                    }
                }
                .onAppear{
                    print("root appear")
                    for goal in goals {
                        goal.checkIn()
                        goal.setup()
                        if goal.type.supportHealthKit {
                            HealthData.healthConfigureBackgroundQuery(for: goal.type.healthIdentifier.rawValue)
                        }
                    }
                }
            }
        }
        .onChange(of: goals.count) {
            print("goal count change: \(goals.count)")
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase, goal: Goal) {
        switch newPhase {
        case .inactive:
            Logger.ui.debug("inactive homeview")
        case .active:
            print("active! \(goal.updateCount) changes: \(modelContext.hasChanges)")
            for parts in goal.participants {
                let da = parts.getTodaysData()
                let lost = Date(timeIntervalSinceReferenceDate: da.goalLost)
                print("\(parts.name)  \(get_time_of_day_LOCAL(date: parts.lastUpdate)) lost: \(get_time_of_day_LOCAL(date: lost)) bypasses: \(da.bypasses) val: \(Int(da.value))")
            }
            Task {
                let record : CKRecord = try await CloudManager.fetchGoal(recordName:goal.ident)
                DispatchQueue.main.async {
                    print("got record, merging \(record.description)")
                    goal.mergeFromServerRecord(record)
                    goal.setLastKnownRecordIfNewer(record)
                }
            }
        case .background:
            //timer.upstream.connect().cancel()
            break
        default:
            break
        }
    }
}

#Preview {
    let container = MainModelContainer().makeContainer()
    return RootView()
        .modelContainer(container)
}
