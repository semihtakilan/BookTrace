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

    public static func register(tokenProvider: (@Sendable () async -> String?)? = nil) {

        Container.shared.environmentManager.register {
            EnvironmentManager()
        }

        // Register Network Configuration
        Container.shared.networkConfiguration.register {
            Container.shared.environmentManager().getCurrentConfiguration()
        }

        // Register Network Logger
        Container.shared.networkLogger.register {
            let config = Container.shared.networkConfiguration()
            return NetworkLogger(
                logLevel: config.logLevel,
                includeHeaders: true,
                includeBody: true,
                includeResponse: true
            )
        }

        // Register Network Service
        Container.shared.networkService.register {
            let configuration = Container.shared.networkConfiguration()
            
            // Build request interceptors
            var requestInterceptors: [RequestInterceptor] = []
            
            // Add logging interceptor
            let loggingInterceptor = LoggingInterceptor(
                logLevel: configuration.logLevel,
                includeHeaders: true,
                includeBody: true,
                includeResponse: true
            )
            requestInterceptors.append(loggingInterceptor)
            
            // Add authentication interceptor if token provider is available
            if let tokenProvider = tokenProvider {
                requestInterceptors.append(
                    AuthenticationInterceptor(tokenProvider: tokenProvider)
                )
            }
            
            // Add request ID interceptor
            requestInterceptors.append(RequestIDInterceptor())
            
            // Add user agent interceptor
            requestInterceptors.append(
                UserAgentInterceptor(
                    appName: "Book Trace",
                    appVersion: "1.0",
                    systemInfo: "iOS"
                )
            )
            
            // Build response interceptors
            var responseInterceptors: [ResponseInterceptor] = []
            
            // Add logging interceptor for responses
            responseInterceptors.append(loggingInterceptor)
            
            // Add response validation interceptor
            responseInterceptors.append(ResponseValidationInterceptor())
            
            return NetworkService(
                configuration: configuration,
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors
            )
        }
    }
    
    /// Register with a standard configuration
    public static func registerStandard(tokenProvider: (@Sendable () async -> String?)? = nil) {
        register(tokenProvider: tokenProvider)
    }
    
    /// Register with custom interceptors
    public static func register(
        tokenProvider: (@Sendable () async -> String?)? = nil,
        customRequestInterceptors: [RequestInterceptor] = [],
        customResponseInterceptors: [ResponseInterceptor] = []
    ) {
        // Register Environment Manager
        Container.shared.environmentManager.register {
            EnvironmentManager()
        }

        // Register Network Configuration
        Container.shared.networkConfiguration.register {
            Container.shared.environmentManager().getCurrentConfiguration()
        }

        // Register Network Logger
        Container.shared.networkLogger.register {
            let config = Container.shared.networkConfiguration()
            return NetworkLogger(
                logLevel: config.logLevel,
                includeHeaders: true,
                includeBody: true,
                includeResponse: true
            )
        }

        // Register Network Service
        Container.shared.networkService.register {
            let configuration = Container.shared.networkConfiguration()
            
            var requestInterceptors = customRequestInterceptors
            var responseInterceptors = customResponseInterceptors
            
            // Add default interceptors if not already included
            let loggingInterceptor = LoggingInterceptor(logLevel: configuration.logLevel)
            
            if !requestInterceptors.contains(where: { $0 is LoggingInterceptor }) {
                requestInterceptors.insert(loggingInterceptor, at: 0)
            }
            
            if let tokenProvider = tokenProvider,
               !requestInterceptors.contains(where: { $0 is AuthenticationInterceptor }) {
                requestInterceptors.append(AuthenticationInterceptor(tokenProvider: tokenProvider))
            }
            
            if !responseInterceptors.contains(where: { $0 is LoggingInterceptor }) {
                responseInterceptors.append(loggingInterceptor)
            }
            
            return NetworkService(
                configuration: configuration,
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors
            )
        }
    }
}

