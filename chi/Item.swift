//
//  Item.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
