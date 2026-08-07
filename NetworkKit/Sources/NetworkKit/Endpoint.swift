import Foundation
import FactoryKit

// MARK: - Endpoint Protocol
public protocol Endpoint: Sendable {
    associatedtype Response: Decodable & Sendable
    var path: String { get set }
    var baseURL: URL { get }
    var httpMethod: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryParameters: [String: String]? { get set }
    var httpBody: HTTPBody? { get }
    var timeout: TimeInterval? { get }
    var requiresAuthentication: Bool { get }
    var cachePolicy: URLRequest.CachePolicy { get }
    func urlRequest() throws -> URLRequest
}

public extension Endpoint {
    var baseURL: URL { Container.shared.environmentManager().currentEnvironment.baseURL }
    var httpMethod: HTTPMethod { .GET }
    var headers: [String: String] { ["Content-Type": "application/json"] }
    var queryParameters: [String: String]? { nil }
    var httpBody: HTTPBody? { nil }
    var timeout: TimeInterval? { 30.0 }
    var requiresAuthentication: Bool { false }
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }

    func urlRequest() throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        if let params = queryParameters, !params.isEmpty {
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw NetworkError.invalidURL() }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        request.cachePolicy = cachePolicy
        if let timeout { request.timeoutInterval = timeout }
        if let httpBody, httpMethod.supportsBody {
            let (data, contentType) = try httpBody.encode()
            request.httpBody = data
            var finalHeaders = headers
            finalHeaders["Content-Type"] = contentType
            request.allHTTPHeaderFields = finalHeaders
        } else {
            request.allHTTPHeaderFields = headers
        }
        return request
    }
}

// MARK: - Interceptor Protocols

public protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

public protocol ResponseInterceptor: Sendable {
    func intercept(_ response: NetworkResponse) async throws -> NetworkResponse
}
