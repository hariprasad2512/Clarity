import AppKit
import SwiftData
import SwiftUI

/// The detail column: capture bar, search, and the task list.
struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext

    var filter: TaskFilter
    var tasks: [TodoTask]

    @State private var newTaskTitle = ""
    @State private var search = ""
    @FocusState private var addFocused: Bool

    /// Manual schedule override (nil = auto-parse from text).
    @State private var manualDate: Date?
    @State private var showSchedulePopover = false
    @State private var scheduleDraft = Date()

    /// The date the chips and save use: manual choice wins, else parsed text.
    private var effectiveDate: Date? {
        manualDate ?? DateParser.extractDate(from: newTaskTitle)
    }

    private var filtered: [TodoTask] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let base: [TodoTask]
        switch filter {
        case .today:
            base = tasks.filter { $0.isDueTodayOrOverdue }
        case .inbox:
            base = tasks.filter { !$0.isCompleted }
        case .done:
            base = tasks.filter(\.isCompleted)
        }
        let searched = q.isEmpty ? base : base.filter { $0.title.lowercased().contains(q) }
        return searched.sorted(by: TodoTask.sortForDisplay)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(filter.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("\(filtered.count)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(8)
                Spacer()
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            // Capture bar: icon + field share one size/baseline, schedule
            // chips sit right in Todoist/Reminders style.
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 15))
                TextField("Add a task — try \"File taxes Friday\"", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .focused($addFocused)
                    .onSubmit { addTask() }

                scheduleChips

                if !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add") { addTask() }
                        .buttonStyle(.plain)
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom, 6)
            .onAppear { addFocused = true }
            .onChange(of: filter) { addFocused = true }

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: filter == .done ? "checkmark.circle" : "sun.max")
                        .font(.system(size: 44))
                        .foregroundColor(.green.opacity(0.6))
                    Text(
                        filter == .today ? "Nothing due today. Enjoy the calm." :
                            filter == .inbox ? "Inbox zero. Press ⌘⇧T anywhere to capture." :
                            "No completed tasks yet."
                    )
                    .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filtered) { task in
                        TaskRowView(task: task)
                    }
                    .onDelete(perform: deleteTasks)
                }
                .scrollContentBackground(.hidden)
            }

            // Store footer
            HStack {
                Text(SharedStore.isSharingEnabled ? "Widget live" : "Enable App Group for widget")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !SharedStore.isSharingEnabled {
                    Text("See README → Signing & Capabilities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .tint(.green)
    }

    // MARK: - Schedule chips (calendar + clock, famous SF Symbols)

    private var scheduleChips: some View {
        HStack(spacing: 6) {
            Button { openSchedule() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(dayLabel)
                }
                .font(.callout)
                .foregroundColor(effectiveDate == nil ? .secondary : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.green.opacity(effectiveDate == nil ? 0.06 : 0.14))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .help("Pick a day")

            Button { openSchedule() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(timeLabel)
                }
                .font(.callout)
                .foregroundColor(effectiveDate == nil ? .secondary : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.green.opacity(effectiveDate == nil ? 0.06 : 0.14))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .help("Pick a time")
        }
        .popover(isPresented: $showSchedulePopover) {
            VStack(alignment: .leading, spacing: 10) {
                // Quick presets: set the day, keep the draft's time-of-day.
                HStack(spacing: 8) {
                    presetChip("Today") {
                        applyPreset(dayOffset: 0)
                    }
                    presetChip("Tomorrow") {
                        applyPreset(dayOffset: 1)
                    }
                    presetChip("Weekend") {
                        applyPresetToWeekend()
                    }
                }

                // Real month calendar.
                DatePicker("", selection: $scheduleDraft, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.green)
                        .frame(width: 20)
                    DatePicker("Time", selection: $scheduleDraft, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                    Spacer()
                }
                HStack {
                    Button("Clear") {
                        manualDate = nil
                        showSchedulePopover = false
                    }
                    .buttonStyle(.link)
                    Spacer()
                    Button("Done") {
                        manualDate = scheduleDraft
                        showSchedulePopover = false
                        addFocused = true
                    }
                    .buttonStyle(.plain)
                    .font(.callout.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(7)
                }
            }
            .padding()
            .frame(width: 320)
        }
    }

    private func presetChip(_ title: String, action: @escaping () -> Void) -> some View {
        // Text-only pills (Todoist-style): icon+text didn't fit one line.
        Button(action: action, label: {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
        })
        .buttonStyle(.plain)
        .help(title)
    }

    private func applyPreset(dayOffset: Int) {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { return }
        let time = cal.dateComponents([.hour, .minute], from: scheduleDraft)
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = time.hour
        comps.minute = time.minute
        scheduleDraft = cal.date(from: comps) ?? day
    }

    private func applyPresetToWeekend() {
        // Upcoming Saturday (today, if it already is Saturday).
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sun … 7=Sat
        applyPreset(dayOffset: (7 - weekday + 7) % 7)
    }

    private func openSchedule() {
        scheduleDraft = manualDate ?? effectiveDate ?? Date()
        showSchedulePopover = true
    }

    private var dayLabel: String {
        guard let date = effectiveDate else { return "Date" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tmrw" }
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: date)
    }

    private var timeLabel: String {
        guard let date = effectiveDate else { return "Time" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Actions

    private func addTask() {
        guard TaskService.add(title: newTaskTitle, manualDate: manualDate, in: modelContext) != nil else { return }
        newTaskTitle = ""
        manualDate = nil
        scheduleDraft = Date()
        addFocused = true
    }

    private func deleteTasks(offsets: IndexSet) {
        let doomed = offsets.compactMap { filtered.indices.contains($0) ? filtered[$0] : nil }
        TaskService.delete(doomed, in: modelContext)
    }
}

struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let task: TodoTask

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(task.isCompleted ? .gray : .green)
                .onTapGesture {
                    TaskService.toggle(task, in: modelContext)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                if let due = task.dueDate {
                    Label(DateParser.displayString(for: due), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(dueColor(for: due))
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(hoverFill)
        .cornerRadius(8)
        .onHover {
            hovered = $0
            if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    /// Adaptive hover: light fill in dark mode, dark fill in light mode.
    private var hoverFill: Color {
        guard hovered else { return Color.clear }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private func dueColor(for date: Date) -> Color {
        if task.isCompleted { return .gray }
        if !Calendar.current.isDateInToday(date) && date < Date() { return .red }
        if Calendar.current.isDateInToday(date) { return .green }
        return .secondary
    }
}
