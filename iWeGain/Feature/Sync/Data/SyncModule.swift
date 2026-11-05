extension AppContainer {
    var syncCursors: SyncCursorDataSource { shared { SyncCursorDataSource(store: store) } }

    /// Exercises first, so trainings that use custom exercises can resolve them.
    private var syncTables: [SyncTable] {
        [
            ExerciseSyncDataSource(store: store),
            TrainingSyncDataSource(store: store),
            ScheduleSyncDataSource(store: store),
            WorkoutSyncDataSource(store: store),
        ]
    }

    var deviceDataSource: DeviceDataSource {
        DeviceDataSource(tables: syncTables, cursors: syncCursors, store: store, firestore: firestore)
    }

    var syncManager: SyncManager {
        shared {
            SyncManager(
                authRepository: authRepository,
                userRepository: userRepository,
                collections: syncTables.map { SyncedCollection(table: $0, firestore: firestore, cursors: syncCursors, store: store) },
                deviceDataSource: deviceDataSource,
                network: network
            )
        }
    }
}
