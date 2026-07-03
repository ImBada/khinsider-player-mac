import AppKit

internal final class TopInsetScroller: NSScroller {
    override internal var isOpaque: Bool {
        false
    }

    internal var topInset: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    internal static func install(on scrollView: NSScrollView, topInset: CGFloat) {
        let scroller: TopInsetScroller

        if let existingScroller = scrollView.verticalScroller as? TopInsetScroller {
            scroller = existingScroller
        } else {
            let replacementScroller = TopInsetScroller(frame: scrollView.verticalScroller?.frame ?? .zero)
            replacementScroller.controlSize = scrollView.verticalScroller?.controlSize ?? .regular
            replacementScroller.autoresizingMask = scrollView.verticalScroller?.autoresizingMask ?? [.height, .minXMargin]
            scrollView.verticalScroller = replacementScroller
            scroller = replacementScroller
        }

        scroller.topInset = topInset
        scrollView.hasVerticalScroller = true

        var scrollerInsets = scrollView.scrollerInsets
        if scrollerInsets.top != 0 {
            scrollerInsets.top = 0
            scrollView.scrollerInsets = scrollerInsets
        }
    }

    override internal func rect(for part: NSScroller.Part) -> NSRect {
        let rect = super.rect(for: part)

        guard part == .knob, topInset > 0 else {
            return rect
        }

        let slot = super.rect(for: .knobSlot)
        guard slot.height > 0 else {
            return rect
        }

        let paddedSlot = topPaddedSlot(from: slot)
        guard paddedSlot.height > 0 else {
            return rect
        }

        let position = (rect.minY - slot.minY) / slot.height
        let height = rect.height / slot.height

        return NSRect(
            x: rect.minX,
            y: paddedSlot.minY + position * paddedSlot.height,
            width: rect.width,
            height: max(0, height * paddedSlot.height)
        )
    }

    private func topPaddedSlot(from slot: NSRect) -> NSRect {
        let inset = min(topInset, max(0, slot.height - 1))
        var paddedSlot = slot

        if isFlipped {
            paddedSlot.origin.y += inset
        }

        paddedSlot.size.height -= inset
        return paddedSlot
    }

    override internal func draw(_ dirtyRect: NSRect) {
        drawKnob()
    }

    override internal func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override internal func drawKnob() {
        let knobRect = rect(for: .knob)
        guard knobRect.width > 0, knobRect.height > 0 else {
            return
        }

        let width: CGFloat = 8
        let horizontalInset = max(0, (knobRect.width - width) / 2)
        let polishedKnobRect = knobRect.insetBy(dx: horizontalInset, dy: 0.5)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color = NSColor(
            calibratedWhite: isDark ? 0.78 : 0.42,
            alpha: isDark ? 0.56 : 0.46
        )
        color.setFill()
        NSBezierPath(
            roundedRect: polishedKnobRect,
            xRadius: polishedKnobRect.width / 2,
            yRadius: polishedKnobRect.width / 2
        ).fill()
    }
}
