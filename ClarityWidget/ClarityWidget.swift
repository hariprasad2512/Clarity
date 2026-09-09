import SwiftData
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline model (lightweight, widget-safe)

struct WidgetTask: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool

    var dueLabel: String? {
        guard let dueDate else { return nil }
        return DateParser.displayString(for: dueDate)
    }
}

struct ClarityEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let totalOpen: Int
}

// MARK: - Provider (reads the SAME App Group store as the app)

struct ClarityProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClarityEntry {
        ClarityEntry(
            date: Date(),
            tasks: [
                WidgetTask(id: "1", title: "Pay rent tomorrow at 5pm", dueDate: Date(), isCompleted: false),
                WidgetTask(id: "2", title: "Call mom", dueDate: nil, isCompleted: false),
            ],
            totalOpen: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ClarityEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClarityEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh at next midnight + whenever the app calls reloadAllTimelines()
        let nextMidnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))
        completion(timeline)
    }

    @MainActor
    private func fetchEntry() -> ClarityEntry {
        let container = SharedStore.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { $0.isCompleted == false },
            sortBy: [
                SortDescriptor(\.createdAt),
            ]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        let all = fetched.sorted(by: TodoTask.sortForDisplay)
        // Today/overdue first, then the rest — same spirit as the main app
        let cal = Calendar.current
        let todayish = all.filter { t in
            t.dueDate.map { cal.compare($0, to: Date(), toGranularity: .day) != .orderedDescending } ?? false
        }
        let rest = all.filter { t in
            !(t.dueDate.map { cal.compare($0, to: Date(), toGranularity: .day) != .orderedDescending } ?? false)
        }
        let ordered = (todayish + rest).prefix(6).map {
            WidgetTask(id: $0.id, title: $0.title, dueDate: $0.dueDate, isCompleted: $0.isCompleted)
        }
        return ClarityEntry(date: Date(), tasks: Array(ordered), totalOpen: all.count)
    }
}

// MARK: - Views

struct WidgetTaskRow: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleTaskIntent(taskID: task.id)) {
                Image(systemName: "circle")
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let label = task.dueLabel {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 2)
        }
    }
}

struct ClarityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClarityEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Clarity", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                Spacer()
                Text("\(entry.totalOpen) open")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if entry.tasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max")
                            .foregroundColor(.green.opacity(0.7))
                        Text("All clear")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(family == .systemSmall ? 3 : 5)) { task in
                    WidgetTaskRow(task: task)
                    if task.id != entry.tasks.prefix(family == .systemSmall ? 3 : 5).last?.id {
                        Divider()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
        .widgetURL(URL(string: "clarity://today"))
        // Required on macOS 14+/Tahoe: without containerBackground the
        // system renders a "Please adopt containerBackground API" placeholder.
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

// MARK: - Widget + Bundle

struct ClarityWidget: Widget {
    let kind = "ClarityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClarityProvider()) { entry in
            ClarityWidgetView(entry: entry)
        }
        .configurationDisplayName("Clarity Tasks")
        .description("Today's tasks. Tap a circle to complete it.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct ClarityWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClarityWidget()
    }
}
