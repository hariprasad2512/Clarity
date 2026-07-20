//
//  Item.swift
//  Clarity
//
//  Created by Hariprasad Anuganti on 20/07/26.
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
