import AppKit
import SwiftUI

internal enum AdaptiveSystemColors {
    internal static var controlBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    internal static var chromeOverlayBackground: Color {
        Color(nsColor: .underPageBackgroundColor)
    }

    internal static var label: Color {
        Color(nsColor: .labelColor)
    }

    internal static var selectedText: Color {
        Color(nsColor: .selectedMenuItemTextColor)
    }

    internal static var separator: Color {
        Color(nsColor: .separatorColor)
    }

    internal static var shadow: Color {
        Color(nsColor: .shadowColor)
    }

    internal static var subtleSelection: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    internal static var rowHoverBackground: Color {
        Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    }

    internal static var rowStripeBackground: Color {
        Color(nsColor: .alternatingContentBackgroundColors[1])
    }

    internal static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }
}
