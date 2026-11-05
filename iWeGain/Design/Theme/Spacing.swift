import CoreGraphics

/// Spacing tokens from the Figma "space" variables.
nonisolated enum Spacing {
    static let x2: CGFloat = 2
    static let x4: CGFloat = 4
    static let x8: CGFloat = 8
    static let x12: CGFloat = 12
    static let x16: CGFloat = 16
    static let x20: CGFloat = 20
    static let x24: CGFloat = 24
    static let x40: CGFloat = 40
}

/// Corner radii from the Figma "radius" variables.
nonisolated enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
}
