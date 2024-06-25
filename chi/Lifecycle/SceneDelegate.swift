//
//  SceneDelegate.swift
//  strive
//
//  Created by Richard Hanger on 12/14/23.
//

import Foundation
import CloudKit
import UIKit
import SwiftUI


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith shareMetaData: CKShare.Metadata) {
        guard shareMetaData.containerIdentifier == Config.cloudContainerIdentifier else {
            print("Shared container identifier \(shareMetaData.containerIdentifier) did not match known identifier.")
            return
        }
        
        let container = CKContainer(identifier: Config.cloudContainerIdentifier)
        let operation = CKAcceptSharesOperation(shareMetadatas: [shareMetaData])
        debugPrint("Accepting CloudKit Share with metadata: \(shareMetaData)")
        
        operation.perShareResultBlock = { metadata, result in
            
            let rootRecordID = metadata.hierarchicalRootRecordID
            switch result {
            case .failure(let error):
                debugPrint("Error accepting share with root record ID: \(String(describing: rootRecordID)), \(error)")
                
            case .success:
                DispatchQueue.main.async {
                    print("appending metadata to path")
                    Router.shared.pendingShare = metadata
                }
                debugPrint("Accepted CloudKit share for root record ID: \(String(describing: rootRecordID))")
            }
        }
        
        operation.acceptSharesResultBlock = { result in
            if case .failure(let error) = result {
                debugPrint("Error accepting CloudKit Share: \(error)")
            }
        }
        
        operation.qualityOfService = .utility
        container.add(operation)
    }
}
