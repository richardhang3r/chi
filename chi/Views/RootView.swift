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
            .onAppear{ 
                print("root appear")
                goals.first?.setup()
            }
            
        }
    }
    
}

#Preview {
    let container = MainModelContainer().makeContainer()
    return RootView()
        .modelContainer(container)
}
