//
//  Item.swift
//  MenuDock
//

import Foundation
import SwiftData

@Model
final class ShortcutApp {
    var id: UUID
    var name: String
    var path: String
    var sortIndex: Int = 0
    
    init(id: UUID = UUID(), name: String, path: String, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.path = path
        self.sortIndex = sortIndex
    }
}
