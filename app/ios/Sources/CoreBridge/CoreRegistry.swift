import SharedKit

public actor CoreRegistry {
    private let adapters: [CoreIdentifier: any CoreRuntimeAdapter]

    public init(adapters: [any CoreRuntimeAdapter]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.identifier, $0) })
    }

    public func adapter(for identifier: CoreIdentifier) -> (any CoreRuntimeAdapter)? {
        adapters[identifier]
    }

    public func availability() -> [CoreIdentifier: CoreHealth] {
        Dictionary(uniqueKeysWithValues: CoreIdentifier.allCases.map { identifier in
            (identifier, CoreHealth(isAvailable: adapters[identifier]?.isLinked == true))
        })
    }

    public nonisolated static func developmentDefault() -> CoreRegistry {
        CoreRegistry(adapters: [
            UnavailableCoreAdapter(identifier: .singBox),
        ])
    }
}
