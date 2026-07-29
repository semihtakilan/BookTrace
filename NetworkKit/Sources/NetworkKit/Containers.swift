import Foundation
import FactoryKit

// MARK: - NetworkKit Container Extensions

public extension Container {
    var environmentManager: Factory<EnvironmentManager> {
        self { EnvironmentManager() }.singleton
    }

    var networkConfiguration: Factory<NetworkConfiguration> {
        self { Container.shared.environmentManager().getCurrentConfiguration() }.cached
    }

    var networkLogger: Factory<NetworkLogger> {
        self {
            NetworkLogger(
                logLevel: Container.shared.environmentManager().currentEnvironment.logLevel
            )
        }.cached
    }

    var networkService: Factory<any NetworkServiceProtocol> {
        self {
            fatalError("NetworkService not registered. Call NetworkKit.register() on app init()")
        }.cached
    }
}

// MARK: - Registration

public enum NetworkKit {
    /// Call once at app launch (inside app init).
    /// - Parameter tokenProvider: Returns current Bearer token, or nil when not authenticated.
    nonisolated public static func register(
        tokenProvider: (@Sendable () async -> String?)? = nil
    ) {
        Container.shared.networkService.register {
            NetworkService.standard(
                configuration: Container.shared.networkConfiguration(),
                tokenProvider: tokenProvider
            )
        }
    }
}
