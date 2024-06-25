//
//  chiApp.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

import SwiftUI
import SwiftData

@main
struct chiApp: App {
    
    let container = MainModelContainer().makeContainer()
    @UIApplicationDelegateAdaptor var appDelegate: MyAppDelegate

    init() {
        // uniquely identify this user on this device
        Config.setUniqueUserId()
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .background(Color.beige)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // checkin at least twice a day
                    //_ = scheduleAppCheckin()
                    scheduleAppMidnight()
                }
        }
        .backgroundTask(.appRefresh("com.hang3r.chi.refresh")) {
            await Goal.backgroundUpdateData()
        }
        .backgroundTask(.appRefresh("com.hang3r.chi.checkin")) {
            await Goal.backgroundUpdateData()
        }
        .backgroundTask(.appRefresh("com.hang3r.chi.midnight")) {
            await Goal.midnightUpdate()
            await Goal.backgroundUpdateData()
        }
    }
}
