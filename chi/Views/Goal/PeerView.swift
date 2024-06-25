//
//  PeerView.swift
//  track
//
//  Created by Richard Hanger on 5/31/24.
//

import SwiftUI
import SwiftData

struct PeerViewRoot: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    let goalid : String

    var body: some View {
        ForEach(goals) {goal in
            if (goal.ident == goalid)  {
                PeerView(goal: goal)
            }
        }
    }
}
struct PeerView: View {
    
    @State var goal: Goal
    @State private var displayCode: Bool = false
    private let dates_to_graph : [Date]  = getLastNumDays(6)
    
    //@Query(filter: #Predicate<Goal>{$0.userId == globalUserId}) var myself: [Goal]
    var body: some View {
        VStack {
            //if let goal = goals.first {
            Text("target: \(Int(goal.target))")
                .font(.title)
            Text("users: \(Int(goal.participants.count))")
                .font(.headline)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    VStack {
                        ForEach(goal.participants) { user in
                            let status = user.getGoalStatus(target: goal.target)
                            VStack {
                                HStack {
                                    let color = goal.getColor(status: status)
                                    Text(user.name)
                                        .font(.caption)
                                        .foregroundStyle(color)
                                    Image(systemName: goal.type.iconName)
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .foregroundStyle(color)
                                        .frame(width: 50, height: 40)
                                    VStack {
                                        let data = user.getTodaysData()
                                        Text("\(Int(data.value)) \(goal.type.descriptionPlural) today")
                                        if data.bypasses > 0 {
                                            Text("\(data.bypasses)x app bypasses")
                                                .foregroundStyle(Color.red)
                                        }
                                    }
                                }
                                HStack {
                                    ForEach(dates_to_graph.sorted(by: <), id: \.timeIntervalSinceReferenceDate) { date in
                                        let status = user.getGoalStatus(target: goal.target, date: date)
                                        rectView(status: status, date: date)
                                    }
                                }
                                Text("\(get_time_of_day_LOCAL(date:user.lastUpdate))")
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
                .onAppear {
                    print("on appear peer view")
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    displayCode.toggle()
                } label: {
                    Label("add users", systemImage: "plus")
                }
            }
        }
        .alert("goal code", isPresented: $displayCode) {
            Button("copy") {
                UIPasteboard.general.string = goal.ident
            }
            //Button(role: .cancel)
        } message: {
            Text("\(goal.ident)")
        }
        .navigationTitle(goal.type.title)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
    }
    
    //    .cornerRadius(10)
    //    .shadow(radius: 5)
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
    @State var goal = Goal(type: GoalType.steps)
   // let user = Peer(goal: goal)
   // goal.addUser(user)
    return PeerView(goal: goal)
}
/*
 struct GoalSummaryPage: View {
     
     @Environment(\.modelContext) private var modelContext
     @Environment(\.dismiss) private var dismiss
     let goal: Goal
     @Binding var isPresented : Bool
     var displayButton: Bool = true
     
     var body: some View {
         VStack(alignment: .leading, spacing: 10) {
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
                 if (!goal.enforceType.blocksApps) {
                     infoRow(label: "Screentime Limit", value: "\(goal.screenTimeLimitMinutes) minutes", icon:  "iphone")
                 }
             }
             if (!goal.peers.isEmpty) {
                 Text("Users: \(goal.peers.count)")
                     .font(.headline)
                     .padding(.top,10)
                     .padding(.bottom,10)
                 Group {
                     ForEach(goal.peers) { peer in
                         infoRow(label: "Name", value: peer.name, icon: "person")
                     }
                 }
             }
             if (displayButton) {
                 Spacer()
                 HStack {
                     Spacer()
                     Button {
                         let peer = Peer(goal: goal)
                         goal.addUser(peer)
                         MyUserDefaults.selectedStreak = goal.id
                         goal.isPrimary = true
                         modelContext.insert(goal)
                         isPresented = false
                         //MyUserDefaults.selectedStreak = goal.id
                         //goal.isPrimary = true
                         //RouterHome.shared.path.removeLast(RouterHome.shared.path.count)
                         //RouterHome.shared.path.append(goal)
                         //Router.shared.selectedStreak = goal.id
                         print("Count \(RouterHome.shared.path.count)")
                     } label: {
                         Text("save goal")
                             .bold()
                             .padding()
                     }
                     .buttonStyle(.bordered)
                     .clipShape(.ellipse)
                     Spacer()
                 }
                 
                 Spacer()
             }
         }
         .onAppear{
         }
         
         .padding()
         .cornerRadius(12)
         .shadow(radius: 5)
     }
     
     

 } 
 
 
  ForEach(goal.participants) { peer in
  VStack {
  let dr = peer.getTodaysData()
  let todayStatus = peer.getGoalStatus(target: goal.target)
  Text("\(peer.name)")
  .font(.headline)
  .padding(.bottom, 10)
  .padding(.top, 10)
  text("\(int(dr.value)) \(goal.type.descriptionplural) today")
  if todayStatus == .passed {
  let timeCompleted = Date(timeIntervalSinceReferenceDate:  dr.timeCompleted)
  Text("completed: \(get_time_of_day_LOCAL(date: timeCompleted))")
  } else if todayStatus == .failed {
  let timeFailed = Date(timeIntervalSinceReferenceDate:  dr.goalLost)
  Text("lost: \(get_time_of_day_LOCAL(date: timeFailed))")
  }
  Text("updated: \(get_full_readable_time_LOCAL(date: peer.lastUpdate))")
  .font(.caption)
  HStack {
  ForEach(dates_to_graph.sorted(by: <), id: \.timeIntervalSinceReferenceDate) { date in
  let status = peer.getGoalStatus(target: goal.target, date: date)
  rectView(status: status, date: date)
  }
  }
  Text("\(peer.currentStreak)x day streak")
  }
  .padding()
  .background(Color(.tertiarySystemGroupedBackground))
  .cornerRadius(10)
  .shadow(radius: 5)
  }
 */
/*
 HStack {
 Spacer()
 Image(systemName: goal.type.iconName)
 Text("\(goal.type.title)")
 .font(.title)
 Spacer()
 }
 Image(systemName: goal.type.iconName)
     .resizable()
     .renderingMode(.template)
     .scaledToFit()
     .frame(width: 42, height: 33)
 */
