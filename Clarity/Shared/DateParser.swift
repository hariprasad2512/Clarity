import Foundation

/// Natural-language date extraction (shared by main window, quick-add bar, widget intent).
enum DateParser {
    /// "Buy groceries tomorrow at 5 PM" -> Date. Date-only matches default to 23:59.
    static func extractDate(from text: String) -> Date? {
        extractDateAndCleaned(from: text).date
    }

    /// Returns the detected date plus the title with date words stripped
    /// (Todoist-style: "Commit Clarity repo at 6.20 pm" -> ("…", "Commit Clarity repo")).
    /// Dotted times ("6.20 pm") are normalized first — NSDataDetector misses them.
    /// If stripping would leave nothing ("tomorrow"), the original text is kept.
    static func extractDateAndCleaned(from text: String) -> (date: Date?, title: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeDottedTime(in: trimmed)
        let range = NSRange(location: 0, length: normalized.utf16.count)
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        guard let match = detector?.matches(in: normalized, options: [], range: range).first,
              let detectedDate = match.date,
              let matchRange = Range(match.range, in: normalized)
        else {
            return (nil, trimmed)
        }

        let matchedString = String(normalized[matchRange]).lowercased()
        let explicitlyMentionsTime = matchedString.contains("am") ||
            matchedString.contains("pm") ||
            matchedString.contains(":") ||
            matchedString.contains("at")

        let date: Date
        if explicitlyMentionsTime {
            date = detectedDate
        } else {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: detectedDate)
            components.hour = 23
            components.minute = 59
            guard let endOfDay = calendar.date(from: components) else {
                return (nil, trimmed)
            }
            date = endOfDay
        }

        var cleaned = normalized.replacingCharacters(in: matchRange, with: "")
        cleaned = collapseWhitespace(cleaned)
        cleaned = stripTrailingPreposition(cleaned)
        guard !cleaned.isEmpty else {
            return (date, trimmed)
        }
        return (date, cleaned)
    }

    /// "6.20 pm" -> "6:20 pm" (only before am/pm, so "v2.0" is untouched).
    private static func normalizeDottedTime(in text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "(\\b\\d{1,2})\\.(\\d{2})(?=\\s*(?:am|pm|a\\.m\\.|p\\.m\\.))",
            options: .caseInsensitive
        ) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1:$2")
    }

    private static func collapseWhitespace(_ s: String) -> String {
        s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Drops a dangling "… repo at" left behind after stripping the date.
    private static func stripTrailingPreposition(_ s: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "\\s+(at|on|by|for|in)$",
            options: .caseInsensitive
        ) else { return s }
        let range = NSRange(s.startIndex..., in: s)
        return regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    }

    /// Human-friendly due label: "Today 5:00 PM", "Tomorrow", "Sep 12", "Overdue".
    static func displayString(for date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Today \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        if date < Date() { return "Overdue · \(date.formatted(date: .abbreviated, time: .shortened))" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
