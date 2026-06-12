import SwiftUI
import AppKit

/// Single source of truth for CopyTranslate's visual language. Replaces the
/// scattered NSColor(white:)/Color.white.opacity() literals across the views.
enum CT {
    enum Palette {
        static let bg = Color(white: 0.08)
        static let bgNS = NSColor(white: 0.08, alpha: 1)
        static let card = Color(white: 0.12)
        static let inset = Color(white: 0.06)
        static let accent = Color(red: 0.43, green: 0.49, blue: 0.96)      // translation indigo
        static let accentNS = NSColor(red: 0.43, green: 0.49, blue: 0.96, alpha: 1)
        static let success = Color(red: 0.30, green: 0.80, blue: 0.55)
        static let hairline = Color.white.opacity(0.08)
        static let textPrimary = Color.white.opacity(0.92)
        static let textSecondary = Color.white.opacity(0.5)
        static let textDim = Color.white.opacity(0.3)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 14
        static let xl: CGFloat = 20
    }

    enum Radius {
        static let s: CGFloat = 4
        static let m: CGFloat = 8
        static let l: CGFloat = 10
    }

    enum Motion {
        static var reduce: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        static var quick: Animation? { reduce ? nil : .easeInOut(duration: 0.15) }
    }
}
