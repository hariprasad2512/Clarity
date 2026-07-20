import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    // 1. Connecting to the SwiftData Brain
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TodoTask]
    
    // 2. State variables for input and manual date selection
    @State private var newTaskTitle: String = ""
    @State private var isManualDateEnabled: Bool = false
    @State private var manualDueDate: Date = Date()

    var body: some View {
        VStack(spacing: 0) {
            
            // 3. The Modern, Big Green Input Area
            VStack(spacing: 12) {
                TextField("What needs to be done?", text: $newTaskTitle)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    .onSubmit {
                        addTask()
                    }
                
                // 4. The Manual Date Toggle & Picker
                HStack {
                    Toggle("Set date & time manually", isOn: $isManualDateEnabled)
                        .toggleStyle(.checkbox)
                        .tint(.green)
                    
                    Spacer()
                    
                    if isManualDateEnabled {
                        DatePicker("", selection: $manualDueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 24)
                
                Button(action: addTask) {
                    Text("Add Task")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.green.opacity(0.15))
            
            // 5. The Visual List (Fully responsive)
            List {
                ForEach(tasks) { task in
                    HStack(spacing: 16) {
                        // The Checkbox (Now manages notifications)
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title)
                            .foregroundColor(.green)
                            .onTapGesture {
                                task.isCompleted.toggle()
                                
                                // Manage the notification based on completion status
                                if task.isCompleted {
                                    cancelNotification(for: task)
                                } else {
                                    scheduleNotification(for: task)
                                }
                            }
                        
                        // The Task Title & Due Date
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.title3)
                                .strikethrough(task.isCompleted)
                                .foregroundColor(task.isCompleted ? .gray : .primary)
                            
                            if let dueDate = task.dueDate {
                                Text(dueDate, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundColor(.green.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .onDelete(perform: deleteTasks)
            }
            .scrollContentBackground(.hidden)
            .background(Color.green.opacity(0.05))
        }
        .frame(minWidth: 450, idealWidth: 600, maxWidth: .infinity, minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        .tint(.green)
        .onAppear {
            requestNotificationPermission()
        }
    }

    

    // 6. Upgraded Save Action
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        
        let finalDate: Date?
        
        if isManualDateEnabled {
            finalDate = manualDueDate
        } else {
            finalDate = extractDate(from: newTaskTitle)
        }
        
        let newTask = TodoTask(title: newTaskTitle, dueDate: finalDate, isCompleted: false)
        modelContext.insert(newTask)

        do {
            try modelContext.save()
        } catch {
            print(error)
        }
        
        
        print("Inserted:", newTask.title)

        print("Tasks count:", tasks.count)
        // Schedule the notification for this specific task
        scheduleNotification(for: newTask)
        
        
        newTaskTitle = ""
        isManualDateEnabled = false
        manualDueDate = Date()
    }

    // 7. Upgraded Delete Action
    private func deleteTasks(offsets: IndexSet) {
        for index in offsets {
            let taskToDelete = tasks[index]
            cancelNotification(for: taskToDelete) // Erase the alert first
            modelContext.delete(taskToDelete)     // Then delete the data
        }
    }
    
    // 8. Time-Aware Date Extractor
    private func extractDate(from text: String) -> Date? {
        let range = NSRange(location: 0, length: text.utf16.count)
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        
        guard let match = detector?.matches(in: text, options: [], range: range).first,
              let detectedDate = match.date else {
            return nil
        }
        
        let matchedString = (text as NSString).substring(with: match.range).lowercased()
        
        let explicitlyMentionsTime = matchedString.contains("am") ||
                                     matchedString.contains("pm") ||
                                     matchedString.contains(":") ||
                                     matchedString.contains("at")
        
        if explicitlyMentionsTime {
            return detectedDate
        } else {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: detectedDate)
            components.hour = 23
            components.minute = 59
            return calendar.date(from: components)
        }
    }

    // 9. Request Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permission granted.")
            } else if let error = error {
                print("Error requesting permission: \(error.localizedDescription)")
            }
        }
    }

    // 10. Schedule the Alert
    private func scheduleNotification(for task: TodoTask) {
        guard let dueDate = task.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Clarity: Task Due"
        content.body = task.title
        content.sound = .default
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: task.id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    // 11. The Eraser: Cancel Pending Notifications
    private func cancelNotification(for task: TodoTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id])
    }
}
