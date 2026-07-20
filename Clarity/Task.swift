import Foundation
import SwiftData

@Model
final class TodoTask {
    var id: String // The permanent nametag for notifications
    var title: String
    var dueDate: Date?
    var isCompleted: Bool
    
    init(title: String, dueDate: Date? = nil, isCompleted: Bool = false) {
        self.id = UUID().uuidString // Automatically generates a unique tracking number
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
}
