import Foundation
import FactoryKit

// MARK: - NetworkKit Container Extensions
public extension Container {
    var networkConfiguration: Factory<NetworkConfiguration> {
        self { NetworkConfiguration(environment: .current) }.cached
    }

    var networkLogger: Factory<NetworkLogger> {
        self { NetworkLogger(logLevel: APIEnvironment.current.logLevel) }.cached
    }

    var networkService: Factory<any NetworkServiceProtocol> {
        self {
            fatalError("NetworkService not registered. Call NetworkRegistrations.register() on app init()")
        }.cached
    }
}
