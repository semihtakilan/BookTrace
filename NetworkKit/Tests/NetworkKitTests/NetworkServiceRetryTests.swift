//
//  NetworkServiceRetryTests.swift
//  NetworkKitTests
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Foundation
import Testing
@testable import NetworkKit

struct NetworkServiceRetryTests {
    @Test func aDetailEndpointCanDisableTransportRetries() async {
        let interceptor = FailingRequestInterceptor()
        let service = makeService(interceptor: interceptor)

        _ = try? await service.execute(RetryTestEndpoint(maximumAttempts: 1))

        #expect(await interceptor.attempts == 1)
    }

    @Test func ordinaryEndpointsKeepTheConfiguredAttemptCount() async {
        let interceptor = FailingRequestInterceptor()
        let service = makeService(interceptor: interceptor)

        _ = try? await service.execute(RetryTestEndpoint())

        #expect(await interceptor.attempts == 3)
    }

    @Test func invalidAttemptCountsStillPerformOneRequest() async {
        let interceptor = FailingRequestInterceptor()
        let service = makeService(interceptor: interceptor)

        _ = try? await service.execute(RetryTestEndpoint(maximumAttempts: 0))

        #expect(await interceptor.attempts == 1)
    }

    @Test func anAlreadyCancelledRequestNeverStartsItsFirstAttempt() async {
        let interceptor = FailingRequestInterceptor()
        let service = makeService(interceptor: interceptor)
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.execute(RetryTestEndpoint())
        }

        do {
            _ = try await request.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(await interceptor.attempts == 0)
    }

    private func makeService(interceptor: FailingRequestInterceptor) -> NetworkService {
        NetworkService(
            configuration: NetworkConfiguration(
                environment: .testing,
                retryCount: 3,
                retryDelay: 0,
                logLevel: LogLevel.none
            ),
            requestInterceptors: [interceptor]
        )
    }
}

private actor FailingRequestInterceptor: RequestInterceptor {
    private(set) var attempts = 0

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        attempts += 1
        throw NetworkError.serverError(statusCode: 503)
    }
}

private struct RetryTestEndpoint: Endpoint {
    struct Response: Decodable, Sendable {}

    var path = "details"
    var queryParameters: [String: String]?
    var baseURL: URL { URL(string: "https://example.com")! }
    var maximumAttempts: Int? = nil
}
