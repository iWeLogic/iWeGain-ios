import Foundation
import Testing
@testable import iWeGain

@MainActor
struct SettingsRepositoryTests {
    private let container = AppContainer.inMemory()

    @Test func defaultsMatchAndroid() {
        #expect(container.settingsRepository.settings == AppSettings(weightUnit: .kg, defaultRestSeconds: 180, workoutReminders: true, reminderMinutesBefore: 30, themeMode: .dark))
    }

    @Test func changesAreSavedAndObserved() async {
        let repository = container.settingsRepository
        var stream = repository.observeSettings().makeAsyncIterator()
        #expect(await stream.next()?.weightUnit == .kg)

        repository.setWeightUnit(.lb)
        #expect(await stream.next()?.weightUnit == .lb)

        repository.setThemeMode(.system)
        repository.setDefaultRestSeconds(90)
        let latest = container.settingsRepository.settings
        #expect(latest.themeMode == .system)
        #expect(latest.defaultRestSeconds == 90)
        // Stored under Android's DataStore keys.
        #expect(container.defaults.string(forKey: "weight_unit") == "Lb")
    }

    @Test func weightConversion() {
        #expect(WeightUnit.kg.fromKg(100) == 100)
        #expect(abs(WeightUnit.lb.fromKg(100) - 220.462) < 0.0001)
        #expect(abs(WeightUnit.lb.toKg(220.462) - 100) < 0.0001)
    }
}
