import SwiftUI

/// Every color token, text style and component of the design system on one page, to compare with Figma.
/// Developer-only: reachable from Settings in debug builds, so its texts aren't localized.
struct DesignCatalogScreen: View {
    @State private var segment = 1

    private static let colors: [(String, Color)] = [
        ("bgBase", .bgBase), ("bgSurface", .bgSurface), ("bgSurface2", .bgSurface2), ("bgTabBar", .bgTabBar),
        ("textPrimary", .textPrimary), ("textSecondary", .textSecondary), ("textTertiary", .textTertiary),
        ("accentPrimary", .accentPrimary), ("accentSoft", .accentSoft), ("accentOn", .accentOn),
        ("switchOn", .switchOn), ("switchOff", .switchOff), ("borderDefault", .borderDefault),
        ("borderGlass", .borderGlass), ("fillSelected", .fillSelected), ("statusSuccess", .statusSuccess),
        ("statusDanger", .statusDanger), ("statusDangerSoft", .statusDangerSoft), ("dataBlue", .dataBlue),
        ("dataPink", .dataPink), ("dataOrange", .dataOrange), ("dataPurple", .dataPurple),
        ("dataBlueSoft", .dataBlueSoft), ("chartBar", .chartBar),
    ]

    private static let textStyles: [(String, AppTextStyle)] = [
        ("Large title", .largeTitle), ("Title 2", .title2), ("Headline", .headline), ("Body", .body),
        ("Callout", .callout), ("Subhead", .subhead), ("Footnote", .footnote), ("Caption", .caption),
        ("Tab label", .tabLabel), ("128", .numericDisplay), ("12,450 kg", .numericLarge), ("1:30", .numericMedium),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x24) {
                section("Icons (picker)") {
                    iconGrid(ItemIcon.allCases.map(\.imageName))
                }
                section("Exercise pictures") {
                    iconGrid(BuiltInExercises.library().map(\.imageName))
                }
                section("Colors") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.x12)], spacing: Spacing.x12) {
                        ForEach(Self.colors, id: \.0) { name, color in
                            VStack(alignment: .leading, spacing: Spacing.x4) {
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .fill(color)
                                    .frame(height: 44)
                                    .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Color.borderDefault))
                                Text(name).textStyle(.caption).foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }
                section("Text styles") {
                    VStack(alignment: .leading, spacing: Spacing.x8) {
                        ForEach(Self.textStyles, id: \.0) { name, style in
                            Text(name).textStyle(style).foregroundStyle(Color.textPrimary)
                        }
                    }
                }
                section("Buttons") {
                    VStack(spacing: Spacing.x12) {
                        Button("Start training", systemImage: "play.fill") {}.buttonStyle(.appPrimary)
                        Button("Edit") {}.buttonStyle(.appSecondary)
                        Button("Delete training") {}.buttonStyle(.appDanger)
                        Button("Disabled") {}.buttonStyle(.appPrimary).disabled(true)
                    }
                }
                section("Segmented control") {
                    AppSegmentedControl(options: ["Week", "Month", "Year"], selectedIndex: segment, onSelect: { segment = $0 })
                }
                section("Card and empty state") {
                    EmptyStateView(
                        title: "No trainings yet",
                        message: "Create your first training: pick exercises, sets and rest time",
                        icon: "ic_dumbbell"
                    )
                    .cardStyle()
                }
            }
            .padding(Spacing.x16)
        }
        .background(Color.bgBase)
        .navigationTitle("Design system")
    }

    private func iconGrid(_ names: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: Spacing.x8)], spacing: Spacing.x8) {
            ForEach(names, id: \.self) { name in
                Image(name)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.bgSurface, in: .rect(cornerRadius: Radius.sm))
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x12) {
            Text(title).textStyle(.headline).foregroundStyle(Color.textPrimary)
            content()
        }
    }
}

#Preview {
    NavigationStack { DesignCatalogScreen() }
}
