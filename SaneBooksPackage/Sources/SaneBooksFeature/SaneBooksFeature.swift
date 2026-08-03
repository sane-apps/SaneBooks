import SaneBooksSync

public enum SaneBooksFeatureBootstrap {
    public static func makeMockSync() -> MockSyncFacade {
        MockSyncFacade()
    }

    public static func makeBlockedSync() -> BlockedSyncFacade {
        BlockedSyncFacade()
    }

    public static func makeLightClientSync() -> LightClientSyncFacade {
        LightClientSyncFacade.makeDefault()
    }
}
