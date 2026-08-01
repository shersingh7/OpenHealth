import SwiftUI

enum OHTheme {
    static let cornerRadius: CGFloat = 16
    static let contentMaxWidth: CGFloat = 760

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    static var primaryAction: Color { Color.accentColor }
    /// Coral/red for health symbols only — not primary CTAs.
    static var healthHighlight: Color { Color(.systemPink) }
    static var cardBackground: Color { Color(.secondarySystemGroupedBackground) }
    static var pageBackground: Color { Color(.systemGroupedBackground) }
    static var separator: Color { Color(.separator) }

    static let minTapTarget: CGFloat = 44
}

struct OHContentWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: OHTheme.contentMaxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func ohContentWidth() -> some View {
        modifier(OHContentWidth())
    }
}
