import SwiftData
import Testing
@testable import iWeGain

@MainActor
struct AppContainerTests {
    @Test func inMemoryContainerOpensTheDatabase() {
        let container = AppContainer.inMemory()
        let inMemory = container.modelContainer.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        #expect(inMemory)
    }
}
