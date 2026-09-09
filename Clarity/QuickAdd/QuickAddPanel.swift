import AppKit

/// NSPanel that can take keyboard focus.
///
/// A plain panel with `.nonactivatingPanel` can never become key, which is
/// why the quick-add field showed no cursor and Enter/Esc were dead.
/// This subclass opts into key/main status so the SwiftUI TextField inside
/// becomes first responder (cursor on, ⏎ submits, esc dismisses).
final class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
