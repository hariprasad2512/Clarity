import SwiftUI
import SwiftData

/// Spotlight-style quick-add content. Fresh instance on every show, so
/// `onAppear` always re-arms focus — the cursor lands in the field the
/// instant ⌘⇧T is pressed. Enter = save, Esc = dismiss.
struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var text: String = ""
    @State private var showDatePicker = false
    @State private var manualDate = Date()
    @FocusState private var isFocused: Bool

    var onDone: (() -> Void)?
    var onHeightChange: ((Bool) -> Void)?

    private var parsedDate: Date? {
        showDatePicker ? manualDate : DateParser.extractDate(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Input row: icon and field share size + baseline so the
            // cursor sits exactly on the text line.
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20, weight: .semibold))
                TextField("What needs to be done?", text: $text)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isFocused)
                    .onSubmit { save() }
                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button { save() } label: {
                        Text("Add")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                if let date = parsedDate {
                    Label(DateParser.displayString(for: date), systemImage: "calendar")
                        .font(.callout)
                        .foregroundColor(.green)
                } else if !text.isEmpty {
                    Label("No date — goes to Inbox", systemImage: "tray")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Label("⌘⇧T anywhere · ⏎ save · esc dismiss", systemImage: "keyboard")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    showDatePicker.toggle()
                    onHeightChange?(showDatePicker)
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(showDatePicker ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Set date manually")
            }

            if showDatePicker {
                DatePicker("", selection: $manualDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
        .padding(4) // room for shadow inside panel
        .onAppear { isFocused = true }
        .onExitCommand { onDone?() }
    }

    private func save() {
        let manual: Date? = showDatePicker ? manualDate : nil
        guard TaskService.add(title: text, manualDate: manual, in: modelContext) != nil else { return }
        text = ""
        showDatePicker = false
        manualDate = Date()
        onHeightChange?(false)
        isFocused = true
        // Keep panel open for rapid entry; Esc or click-away closes.
    }
}
