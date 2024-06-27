//
//  GoalViewModel.swift
//  chi
//
//  Created by Richard Hanger on 6/23/24.
//

import Foundation
import CloudKit
import os.log




import Foundation
import CloudKit

class GoalViewModel: ObservableObject {
    
    
    @Published var state: CloudKitState = .idle
    @Published var goals: [Goal] = []
    private var database = Config.cloudContainer.publicCloudDatabase
    //private let fetchQueue = DispatchQueue(label: "fetchQueue")
    
    func fetchGoals() {
        print("fetching goals")
        let query = CKQuery(recordType: "Goal", predicate: NSPredicate(value: true))
        let operation = CKQueryOperation(query: query)
        
        var fetchedGoals: [Goal] = []
        
        operation.recordMatchedBlock = { reco, res in
            print("found reocrd")
            switch res {
            case .success(let record):
                if let goal = Goal(record: record) {
                    fetchedGoals.append(goal)
                } else {
                    Logger.database.error("invalid record \(record.debugDescription)")
                }
                break;
            case .failure(let error):
                Logger.database.error("query failure: \(error.localizedDescription)")
                break;
            }
        }
        
        
        operation.queryResultBlock = { res in
            switch res {
            case .success(let cursor):
                print("success cursor \(cursor.debugDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.goals = fetchedGoals
                }
                break;
            case .failure(let error):
                print("error! \(error.localizedDescription)")
                break;
            }
        }
        
        database.add(operation)
    }
}
