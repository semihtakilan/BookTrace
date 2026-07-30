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
