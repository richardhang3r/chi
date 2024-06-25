//
//  GoalExtension.swift
//  track
//
//  Created by Richard Hanger on 5/24/24.
//

import Foundation
import HealthKit
import ManagedSettings
import os.log
import SwiftData
import CloudKit
import SwiftUI

extension Goal {
    
    func addUser(_ peer: Peer) {
        if (self.participants.contains(where: {$0.userId == peer.userId})) {
            Logger.database.warning("goal already has user in array \(peer.userId)")
        } else {
            self.participants.append(peer)
        }
    }
    
    func getLocalUserStatus() -> GoalStatus {
        let status : GoalStatus
        if let localUser = self.participants.first(where: {$0.userId == globalUserId}) {
            status = localUser.getGoalStatus(target: self.target)
        } else {
            status = .absent
        }
        return status
    }
    
    func getLocalUser() -> Peer? {
        return self.participants.first(where: {$0.userId == globalUserId})
    }
    
    
    func getColor(status: GoalStatus) -> Color {
        let color: Color
        switch status {
        case .failed:
            color = .red
            break
        case .passed:
            color = Color.accentColor
            break
        case .pending:
            color = Color.accentColor
            //color = Color.yellow
            break
        case .absent:
            color = Color.primary
            break
        }
        return color
    }

    func getImage(status: GoalStatus) -> Image {
        let image: Image
        switch status {
        case .failed:
            image = Image("sad-person")
            break
        case .passed:
            image = Image("celebrate-person")
            break
        case .pending:
            image = self.type.isSystemIcon ? Image(systemName: self.type.iconName) : Image(self.type.iconName)
            break
        case .absent:
            image = Image(systemName: "person.slash")
            break
        }
        return image
    }
    
    func updateData(val: Double, date: Date) -> Bool {
        let justCompleted : Bool
        print("updating data \(val)")
        if let me = self.participants.firstIndex(where: {$0.userId == globalUserId}) {
            self.record.userModificationDate = Date.now
            self.participants[me].lastUpdate = Date.now
            justCompleted = self.participants[me].setNewValue(val: val, date: date, target: self.target)
            self.updateSharedDefaults()
        } else {
            justCompleted = false
            Logger.dataModel.error("failed to find myself for goal \(self.ident)")
        }
        return justCompleted
    }

    func manualUpdate() {
        if self.type.supportHealthKit {
            HealthData.health_data_update(dataType: self.type.healthIdentifier.rawValue)
        }
    }
    func syncUpdate() async {
        do {
            if self.type.supportHealthKit {
                let data = try await HealthData.healthUpdateAsync(dataType: self.type.healthIdentifier.rawValue)
                Logger.healthKit.info("health data sync returned \(data.count)")
                for datum in data {
                    _ = self.updateData(val: datum.value, date: datum.startDate)
                }
            }
        } catch(let error) {
            print("error: \(error)")
        }
    }
    
    func teardown() {
        if (self.type.supportHealthKit) {
            //HealthData.health_configure_background_query(dataType: self.type.healthIdentifier.rawValue)
            var healthTypes : [String] = MyUserDefaults.healthTypeObserverQueries
            healthTypes.removeAll(where: {$0.isEmpty || $0 == self.type.healthIdentifier.rawValue})
            if (!healthTypes.contains(self.type.healthIdentifier.rawValue)) {
                healthTypes.append(self.type.healthIdentifier.rawValue)
                MyUserDefaults.healthTypeObserverQueries = healthTypes
            } else {
                print("already contains \(healthTypes.description)")
            }
        }
        self.updateSharedDefaults()
    }
    
    func setup() {
        if (self.type.supportHealthKit) {
            //HealthData.health_configure_background_query(dataType: self.type.healthIdentifier.rawValue)
            var healthTypes : [String] = MyUserDefaults.healthTypeObserverQueries
            healthTypes.removeAll(where: {$0.isEmpty})
            if (!healthTypes.contains(self.type.healthIdentifier.rawValue)) {
                healthTypes.append(self.type.healthIdentifier.rawValue)
                MyUserDefaults.healthTypeObserverQueries = healthTypes
            } else {
                print("already contains \(healthTypes.description)")
            }
        }
        
        self.updateSharedDefaults()
        let val = self.getLocalUserValue()
        if self.enforceType.blocksApps && val < self.target {
            let selection = MyUserDefaults.loadSelection()
            //let store = ManagedSettingsStore(named: .init(rawValue: self.type.title_string))
            // todo: have custom settings for each goal
            let store = ManagedSettingsStore()
            store.shield.applications = selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens
            print("restricting apps")
        }
        //self.manualUpdate()
        ActivityMonitor.setDailyEvent(thresholdMinutes: 1000)
    }
    
    static func getActiveGoal() async -> Goal? {
        return await getAllGoals()?.first
    }
    
    static func getAllGoals() async -> [Goal]? {
        await MainActor.run {
            let modelContext = MainModelContainer().makeContainer().mainContext
            return try? modelContext.fetch(FetchDescriptor<Goal>())
        }
    }

    func cloudUpdate() {
        Task {
            // save goal record
            // save record
        }
    }
    
    static func midnightUpdate () async {
        await MainActor.run {
            let modelContext = MainModelContainer().makeContainer().mainContext
            if let goals = try? modelContext.fetch(FetchDescriptor<Goal>()) {
                for goal in goals {
                    goal.setup()
                    goal.updateSharedDefaults()
                }
            }
            // save record
            NotificationManager.notifyFromActivityMonitor(message: "midnight update")
        }
    }
    static func backgroundUpdateData() async {
        // update health data
        if let goals = await getAllGoals() {
            for goal in goals {
                do {
                    try await CloudManager.saveToCloud(goal: goal)
                } catch(let error) {
                    print("error saving \(error)")
                }
            }
            // save record
            NotificationManager.notifyFromActivityMonitor(message: "bkgrd saved \(goals.count) to server")
        } else {
            NotificationManager.notifyFromActivityMonitor(message: "failed to get selected goal from background!")
        }
    }
}
