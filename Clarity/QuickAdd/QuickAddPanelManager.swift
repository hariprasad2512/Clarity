import AppKit
import SwiftData
import SwiftUI

/// Floating top-center panel hosting QuickAddView — the Spotlight bar.
///
/// Spotlight behavior, point by point:
/// - floats above everything (`.popUpMenu` level: over fullscreen apps and
///   menu-bar popups, never over the lock screen), on all Spaces;
/// - a fresh key-capable `QuickAddPanel` per show, so the field always
///   takes focus (cursor on, ⏎ submits, esc dismisses);
/// - hides on click-away / app switch, like Spotlight.
@MainActor
final class QuickAddPanelManager: NSObject {
    static let shared = QuickAddPanelManager()

    private var panel: QuickAddPanel?
    private var container: ModelContainer?

    private let width: CGFloat = 660
    private let baseHeight: CGFloat = 152
    private let expandedHeight: CGFloat = 208

    private override init() { super.init() }

    func configure(container: ModelContainer) {
        self.container = container
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let container else {
            print("QuickAddPanelManager: no container — call configure() first")
            return
        }
        hide() // drop any stale panel; every show is a fresh focusable bar

        let content = QuickAddView(
            onDone: { [weak self] in self?.hide() },
            onHeightChange: { [weak self] expanded in self?.resize(expanded: expanded) }
        )
        .modelContainer(container)

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let p = QuickAddPanel(
            contentRect: frame(height: baseHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false // the SwiftUI card draws its own shadow
        p.hidesOnDeactivate = true
        p.contentView = hosting

        hosting.leadingAnchor.constraint(equalTo: p.contentView!.leadingAnchor).isActive = true
        hosting.trailingAnchor.constraint(equalTo: p.contentView!.trailingAnchor).isActive = true
        hosting.topAnchor.constraint(equalTo: p.contentView!.topAnchor).isActive = true
        hosting.bottomAnchor.constraint(equalTo: p.contentView!.bottomAnchor).isActive = true

        self.panel = p
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Geometry (top edge pinned, grows downward)

    private func frame(height: CGFloat) -> NSRect {
        let vis = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let top = vis.maxY - vis.height * 0.22
        return NSRect(x: vis.midX - width / 2, y: top - height, width: width, height: height)
    }

    private func resize(expanded: Bool) {
        guard let panel else { return }
        let height = expanded ? expandedHeight : baseHeight
        var f = panel.frame
        let top = f.maxY
        f.size.height = height
        f.origin.y = top - height
        panel.setFrame(f, display: true, animate: true)
    }
}
