import SwiftUI
import FactoryKit

// MARK: - Environment Manager

public final class EnvironmentManager: ObservableObject {
    @Published public private(set) var currentEnvironment: APIEnvironment

    private static let environmentKey = "APIEnvironment"
    private let lock = NSLock()

    nonisolated(unsafe) public static let shared = EnvironmentManager()

    public init() {
        #if DEBUG
        let defaultEnv = APIEnvironment.development
        #else
        let defaultEnv = APIEnvironment.production
        #endif

        if let saved = UserDefaults.standard.string(forKey: Self.environmentKey),
           let env = APIEnvironment(rawValue: saved) {
            self.currentEnvironment = env
        } else {
            self.currentEnvironment = defaultEnv
        }
    }

    @MainActor
    public func setEnvironment(_ environment: APIEnvironment) {
        currentEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: Self.environmentKey)
        Container.shared.reset()
    }

    public func getCurrentConfiguration() -> NetworkConfiguration {
        lock.lock()
        defer { lock.unlock() }
        return NetworkConfiguration(environment: currentEnvironment)
    }

    public func getCurrentEnvironment() -> APIEnvironment {
        lock.lock()
        defer { lock.unlock() }
        return currentEnvironment
    }
}
