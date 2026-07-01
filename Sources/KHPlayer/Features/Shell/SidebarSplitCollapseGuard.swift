import AppKit
import SwiftUI

@MainActor
internal struct SidebarSplitCollapseGuard: NSViewRepresentable {
    let minimumThickness: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            context.coordinator.configureSplitView(from: view, minimumThickness: minimumThickness)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            context.coordinator.configureSplitView(from: nsView, minimumThickness: minimumThickness)
        }
    }

    final class Coordinator: NSObject {
        private weak var sourceView: NSView?
        private weak var observedItem: NSSplitViewItem?
        private weak var splitView: NSSplitView?
        private var minimumThickness: CGFloat = 0
        private var restoreTimer: Timer?

        deinit {
            restoreTimer?.invalidate()
        }

        @MainActor
        func configureSplitView(from view: NSView, minimumThickness: CGFloat) {
            sourceView = view
            self.minimumThickness = minimumThickness
            startRestoringCollapsedSidebar()

            let splitViewController = nearestSplitViewController(from: view)
            let item = splitViewController?.splitViewItems.first
            guard let splitView = splitViewController?.splitView ?? nearestSplitView(from: view) else {
                return
            }

            self.splitView = splitView

            if let splitViewController {
                splitViewController.minimumThicknessForInlineSidebars = minimumThickness
            }

            if let item {
                item.canCollapse = false
                item.canCollapseFromWindowResize = false
                item.minimumThickness = minimumThickness
                observedItem = item
            }

            restoreSidebar(item)
        }

        @MainActor
        private func startRestoringCollapsedSidebar() {
            guard restoreTimer == nil else {
                return
            }

            restoreTimer = Timer.scheduledTimer(
                timeInterval: 0.1,
                target: self,
                selector: #selector(restoreCollapsedSidebar),
                userInfo: nil,
                repeats: true
            )
        }

        @objc @MainActor private func restoreCollapsedSidebar() {
            if splitView == nil, let sourceView {
                configureSplitView(from: sourceView, minimumThickness: minimumThickness)
            }

            guard observedItem != nil || splitView != nil else {
                return
            }

            restoreSidebar(observedItem)
        }

        @MainActor
        private func restoreSidebar(_ item: NSSplitViewItem?) {
            if let item, item.isCollapsed {
                item.isCollapsed = false
            }

            guard
                let splitView,
                splitView.subviews.indices.contains(0),
                splitView.subviews[0].frame.width < minimumThickness
            else {
                return
            }

            splitView.setPosition(minimumThickness, ofDividerAt: 0)
        }

        @MainActor
        private func nearestSplitViewController(from view: NSView) -> NSSplitViewController? {
            if let contentViewController = view.window?.contentViewController,
               let splitViewController = findSplitViewController(in: contentViewController) {
                return splitViewController
            }

            for window in NSApp.windows {
                if let contentViewController = window.contentViewController,
                   let splitViewController = findSplitViewController(in: contentViewController) {
                    return splitViewController
                }
            }

            var responder: NSResponder? = view
            while let currentResponder = responder {
                if let splitViewController = currentResponder as? NSSplitViewController {
                    return splitViewController
                }

                if let viewController = currentResponder as? NSViewController,
                   let splitViewController = findSplitViewController(in: viewController) {
                    return splitViewController
                }

                responder = currentResponder.nextResponder
            }

            return nil
        }

        @MainActor
        private func nearestSplitView(from view: NSView) -> NSSplitView? {
            if let contentView = view.window?.contentView,
               let splitView = findSplitView(in: contentView) {
                return splitView
            }

            for window in NSApp.windows {
                if let contentView = window.contentView,
                   let splitView = findSplitView(in: contentView) {
                    return splitView
                }
            }

            var currentView: NSView? = view
            while let candidate = currentView {
                if let splitView = candidate as? NSSplitView {
                    return splitView
                }

                if let splitView = findSplitView(in: candidate) {
                    return splitView
                }

                currentView = candidate.superview
            }

            return nil
        }

        @MainActor
        private func findSplitView(in view: NSView) -> NSSplitView? {
            if let splitView = view as? NSSplitView {
                return splitView
            }

            for subview in view.subviews {
                if let splitView = findSplitView(in: subview) {
                    return splitView
                }
            }

            return nil
        }

        @MainActor
        private func findSplitViewController(in viewController: NSViewController) -> NSSplitViewController? {
            if let splitViewController = viewController as? NSSplitViewController {
                return splitViewController
            }

            for child in viewController.children {
                if let splitViewController = findSplitViewController(in: child) {
                    return splitViewController
                }
            }

            return nil
        }
    }
}
