//
//  NetworkRegistration
//  NetworkRegistration
//
//  Created by Batuhan Baran on 1.07.2025.
//

import Foundation
import FactoryKit
import NetworkKit

public struct NetworkRegistrations {

    public static func register(
        tokenProvider: (@Sendable () async -> String?)? = nil,
        customRequestInterceptors: [RequestInterceptor] = [],
        customResponseInterceptors: [ResponseInterceptor] = []
    ) {
        Container.shared.environmentManager.register {
            EnvironmentManager()
        }

        Container.shared.networkConfiguration.register {
            Container.shared.environmentManager().getCurrentConfiguration()
        }

        Container.shared.networkLogger.register {
            let config = Container.shared.networkConfiguration()
            return NetworkLogger(
                logLevel: config.logLevel,
                includeHeaders: true,
                includeBody: true,
                includeResponse: true
            )
        }

        Container.shared.networkService.register {
            let configuration = Container.shared.networkConfiguration()

            var requestInterceptors = customRequestInterceptors

            if let tokenProvider,
               !requestInterceptors.contains(where: { $0 is AuthenticationInterceptor }) {
                requestInterceptors.append(AuthenticationInterceptor(tokenProvider: tokenProvider))
            }
            requestInterceptors.append(RequestIDInterceptor())
            requestInterceptors.append(
                UserAgentInterceptor(appName: "Book Trace", appVersion: "1.0", systemInfo: "iOS")
            )

            var responseInterceptors = customResponseInterceptors
            responseInterceptors.append(ResponseValidationInterceptor())

            return NetworkService(
                configuration: configuration,
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors
            )
        }
    }
}
