import Foundation

/// Tabs of the tab bar, in display order (the same as Android).
enum AppTab: Hashable, CaseIterable {
    case home, statistics, calendar, settings

    var title: LocalizedStringResource {
        switch self {
        case .home: "tab_home"
        case .statistics: "tab_statistics"
        case .calendar: "tab_calendar"
        case .settings: "tab_settings"
        }
    }

    /// The name analytics logs for this tab's first screen.
    var screenName: String {
        switch self {
        case .home: "Home"
        case .statistics: "Statistics"
        case .calendar: "Calendar"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .statistics: "chart.bar.fill"
        case .calendar: "calendar"
        case .settings: "gearshape.fill"
        }
    }
}
