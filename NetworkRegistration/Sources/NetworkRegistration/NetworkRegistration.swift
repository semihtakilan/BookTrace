//
//  NetworkRegistration.swift
//  NetworkRegistration
//
//  Created by Semih TAKILAN on 30.07.2026.
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
        Container.shared.networkConfiguration.register {
            NetworkConfiguration(environment: .current)
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

            // Durum kodu doğrulaması `NetworkService` içinde, interceptor'lardan
            // önce yapılıyor; ayrı bir doğrulama interceptor'ı onu gölgeliyordu.
            let responseInterceptors = customResponseInterceptors

            return NetworkService(
                configuration: configuration,
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors
            )
        }
    }
}
