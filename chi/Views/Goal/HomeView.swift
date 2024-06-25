//
//  HomeView.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import SwiftUI
import SwiftData
import os.log
import CloudKit


struct HomeViewRoot: View {
    
    let goalid: String
    
    @Query private var goals: [Goal]
    @Environment(\.modelContext) private var modelContext
    
    @Environment(\.scenePhase) var scenePhase
    @State private var authenticated: Bool = false
    @State private var passcodeView: Bool = false

    var body: some View {
        TabView {
            ForEach(goals) { goal in
                VStack {
                    HomeView(goal: goal, authenticated: $authenticated)
                        .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase, goal: goal)}
                        .onReceive(NotificationCenter.default.publisher(for: .healthKitDataUpdate, object: nil)) { notification  in updateUserHealthData(notification: notification, goal: goal) }
                }
                .onAppear {
                    handleOnAppear(goal: goal)
                }
                .sheet(isPresented: $passcodeView) {
                    passcodeSheet(goal: goal)
                }
                .onChange(of: authenticated) {
                    handleAuthenticationChange()
                }
                .toolbar {
                    buildPrincipalToolbar(goal: goal)
                    buildCancellationToolbar(goal: goal)
                    if authenticated {
                        buildMenuToolbar()
                    }
                    buildAutomaticToolbar(goal: goal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.beige)
        .tabViewStyle(.page)
        .navigationDestination(for: Goal.self) { _goal in
            PeerViewRoot(goalid: _goal.ident)
        }
        .navigationDestination(for: String.self) { stringtype in
            // Camera support disabled placeholder
            Text("camera support disabled")
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
    private func updateUserHealthData(notification: Notification, goal: Goal) {
        Logger.healthKit.debug("Health Kit Data Update")
        guard let raw = notification.userInfo?[UserInfoKey.healthKitChanges],
              let changes = raw as? [HealthDateData] else {
            print("\(#function): Failed to retrieve the container event from notification.userInfo.")
            return
        }
        for health in changes {
            Logger.healthKit.info("Updating \(health.type) with val \(health.value) start: \(health.startDate) end \(health.endDate)")
            _ = goal.updateData(val: health.value, date: health.startDate)
        }
    }


    private func handleOnAppear(goal: Goal) {
        print("root home on appear!")
        authenticated = goal.goalPasscode.isEmpty
    }

    private func passcodeSheet(goal: Goal?) -> some View {
        if let goal = goal {
            return AnyView(
                PasscodeView(correctCode: goal.goalPasscode, isAuthenticated: $authenticated)
                    .background(Color.beige)
                    .edgesIgnoringSafeArea(.all)
            )
        } else {
            return AnyView(Text("Unauthorized access"))
        }
    }

    private func handleAuthenticationChange() {
        print("isAuthenticated changed! \(authenticated)")
        passcodeView = false
    }

    private func buildMenuToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
              NavigationLink {
                  FetchExistingGoal()
              } label: {
                  Label("menu", systemImage: "line.3.horizontal")
              }
          }
      }
    
    private func buildPrincipalToolbar(goal: Goal) -> some ToolbarContent {
          ToolbarItem(placement: .principal) {
              Button {
                  toggleAuthentication(goal: goal)
              } label: {
                  if authenticated {
                      Label("locked", systemImage: "lock.open")
                  } else {
                      Label("locked", systemImage: "lock")
                  }
              }
          }
      }

      private func buildCancellationToolbar(goal: Goal) -> some ToolbarContent {
          ToolbarItem(placement: .cancellationAction) {
              Button {
                  leaveGoal(goal: goal)
              } label: {
                  Label("trash", systemImage: "trash")
              }
              .disabled(!authenticated)
          }
      }

      private func buildAutomaticToolbar(goal: Goal) -> some ToolbarContent {
          ToolbarItem(placement: .automatic) {
              Button {
                  // Camera button action placeholder
              } label: {
                  Label("camera", systemImage: "camera")
              }
              .disabled(goal.type.supportHealthKit)
          }
      }
    
    private func toggleAuthentication(goal: Goal) {
        if authenticated {
            authenticated = goal.goalPasscode.isEmpty
        } else {
            passcodeView.toggle()
        }
    }

    private func leaveGoal(goal: Goal) {
        Task {
            do {
                if let record = goal.lastKnownRecord {
                    try await CloudManager.removeFromGoal(userId: globalUserId, recordId: record.recordID)
                }
                MyUserDefaults.clear_all_enforcement()
                goal.teardown()
                modelContext.delete(goal)
            } catch {
                print("failed to leave goal \(goal)")
            }
        }
    }
}


struct HomeView: View {
    
    //@State var goal: Goal
    let goal : Goal
    @Binding var authenticated: Bool

    /* ------------
     Timer Logic
     --------------
    private let maxFireCount = 1
    @State private var fireCount = 0
    @State private var timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private func restartTimer() {
        print("restarting timer")
        fireCount = 0
        timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    }
    
    private func handleTimer() {
        Logger.ui.debug("timer callback fired")
        //updateCloudData()
        fireCount += 1
        if fireCount >= maxFireCount {
            timer.upstream.connect().cancel()
        }
    }
    
    private func updateCloudData() {
        let me = goal.getLocalUser()!
        let recordid = goal.lastKnownRecord!.recordID
        Task {
            do {
                try await CloudManager.updateUser(me: me, recordId: recordid)
            } catch (let error) {
                print("failed to save to cloud \(error)")
            }
        }
    }
     .onReceive(timer) { _ in handleTimer() }
     -----------
     End Timer Logic
     ------------- */
    
    
    var body: some View {
            VStack {
                //syncButton
                NavigationLink(value: goal) {
                    HStack {
                        ForEach(goal.participants) { user in
                            if (user.userId != globalUserId) {
                                let status = user.getGoalStatus(target: goal.target)
                                VStack {
                                    let color = goal.getColor(status: status)
                                    Image(systemName: goal.type.iconName)
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .foregroundStyle(color)
                                        .frame(width: 50, height: 40)
                                    Text(user.name)
                                        .font(.caption)
                                        .foregroundStyle(color)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                NavigationLink(value: goal) {
                    let status = goal.getLocalUserStatus()
                    let color = goal.getColor(status: status)
                    Image(systemName: goal.type.iconName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(color)
                }
                editButton
                Spacer()
                if authenticated {
                    BlockedAppsView(disabled: false)
                } else {
                    BlockedAppsView(disabled: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.beige)
            .onAppear {
                print("homeview internal appear!")
            }
    }
    
    func goalText(target: Double, vals: DataRecord) -> String {
        if (vals.value < goal.target) {
            return "\(Int(goal.target - vals.value)) \(goal.type.descriptionPlural) to go"
        } else {
            let completedTime : Date? = Date(timeIntervalSinceReferenceDate: vals.timeCompleted)
            return "passed \(get_time_of_day_LOCAL(date: completedTime))"
        }
    }
    
    private var editButton: some View {
        NavigationLink(value: goal) {
            VStack {
                if let me = goal.participants.first(where: {$0.userId == globalUserId}) {
                    let status = me.getGoalStatus(target: goal.target)
                    let today = me.getTodaysData()
                    let dates_to_graph : [Date]  = getLastNumDays(6)
                    switch (status) {
                    case .failed:
                        Text("\(goal.type.descriptionPlural) failed \(get_time_of_day_LOCAL(date: Date(timeIntervalSinceReferenceDate: today.goalLost)))")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .padding(.bottom, 8)
                            .foregroundStyle(.red)
                        HStack {
                            ForEach(dates_to_graph.sorted(by: <), id: \.timeIntervalSinceReferenceDate) { date in
                                let status = me.getGoalStatus(target: goal.target, date: date)
                                rectView(status: status, date: date)
                            }
                        }
                    case .passed, .pending, .absent:
                        let val = today.value
                        Text(val < goal.target ? "\(goal.type.description) to unlock" : "\(goal.type.description) complete")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .padding(.bottom, 8)
                        HStack {
                            ForEach(dates_to_graph.sorted(by: <), id: \.timeIntervalSinceReferenceDate) { date in
                                let status = me.getGoalStatus(target: goal.target, date: date)
                                rectView(status: status, date: date)
                            }
                        }
                        Text(goalText(target: goal.target, vals: today))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        if goal.target > val {
                            ProgressBar(value: Double(val), total: Double(goal.target), include_text: false)
                                .frame(height: 10)
                                .padding(.top, 5)
                                .padding(.horizontal, 50)
                        } else {
                            Text("\(me.currentStreak)x day streak")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    if today.bypasses > 0 {
                        Text("\(today.bypasses)x app bypasses")
                            .font(.headline)
                            .foregroundStyle(Color.red)
                    }
                } else {
                    Text("not present in goal")
                }
            }
        }
    }
    private func color(for status: GoalStatus) -> Color {
        switch status {
        case .passed:
            return .green
        case .failed:
            return .red
        case .pending:
            return .yellow
        case .absent:
            return Color(.systemBackground)
        }
    }
    
    private func rectView(status: GoalStatus, date: Date) -> some View {
        let weekday = weekdayString(date: date)
        return VStack {
            Rectangle()
                .fill(color(for: status))
                .frame(width: 20, height: 20)
            Text(weekday)
                .font(.caption)
        }
    }
}

#Preview {
//    let container = MainModelContainer().makeContainer()
    @State var authenticated: Bool = false
    return  HomeView(goal: Goal(), authenticated: $authenticated)
 //       .modelContainer(container)
}

/*            .refreshable {
                Task {
                    do {
                        let record = try await CloudManager.fetchGoal(recordName:goal.ident)
                        print("got record, merging \(record.description)")
                        DispatchQueue.main.async {
                            goal.mergeFromServerRecord(record)
                            goal.setLastKnownRecordIfNewer(record)
                        }
                    } catch {
                        print("\(error)")
                    }
                }
            }
                 /*
                 ToolbarItem(placement: .cancellationAction) {
                 Button {
                 Task {
                 do {
                 let record = try await CloudManager.fetchGoal(recordName:goal.ident)
                 ActivityMonitor.setDailyEvent(thresholdMinutes: 1000)
                 print("got record, merging \(record.description)")
                 DispatchQueue.main.async {
                 goal.mergeFromServerRecord(record)
                 goal.setLastKnownRecordIfNewer(record)
                 print("merged")
                 }
                 } catch {
                 print("\(error)")
                 }
                 }
                 } label: {
                 Label("refresh", systemImage: "arrow.clockwise")
                 }
                 }
                 */

 
 
 */

