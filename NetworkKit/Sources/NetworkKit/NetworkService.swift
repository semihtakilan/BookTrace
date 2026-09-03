import Foundation

// MARK: - Network Service Protocol

public protocol NetworkServiceProtocol: Sendable {
    func execute<T: Endpoint>(_ endpoint: T) async throws -> T.Response
}

// MARK: - Network Service

public actor NetworkService: NetworkServiceProtocol {
    private let urlSession: URLSession
    private let configuration: NetworkConfiguration
    private let jsonDecoder: JSONDecoder
    private let requestInterceptors: [RequestInterceptor]
    private let responseInterceptors: [ResponseInterceptor]
    private let logger: NetworkLogger?

    /// - Parameter jsonDecoder: Pass a custom decoder to override date/key strategies.
    ///   Defaults to `.convertFromSnakeCase` + `.iso8601`.
    public init(
        configuration: NetworkConfiguration,
        jsonDecoder: JSONDecoder? = nil,
        requestInterceptors: [RequestInterceptor] = [],
        responseInterceptors: [ResponseInterceptor] = []
    ) {
        self.configuration = configuration
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.waitsForConnectivity = true
        sessionConfig.requestCachePolicy = .useProtocolCachePolicy
        sessionConfig.httpAdditionalHeaders = configuration.defaultHeaders
        self.urlSession = URLSession(configuration: sessionConfig)

        if let jsonDecoder {
            self.jsonDecoder = jsonDecoder
        } else {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            d.dateDecodingStrategy = .iso8601
            self.jsonDecoder = d
        }

        self.logger = configuration.logLevel.rawValue > LogLevel.none.rawValue
            ? NetworkLogger(logLevel: configuration.logLevel)
            : nil
    }

    // MARK: - Execute

    public func execute<T: Endpoint>(_ endpoint: T) async throws -> T.Response {
        let urlRequest = try endpoint.urlRequest()

        let networkResponse = try await withRetry(
            maxAttempts: configuration.retryCount,
            retryDelay: configuration.retryDelay
        ) {
            try await self.performRequest(urlRequest)
        }

        do {
            return try jsonDecoder.decode(T.Response.self, from: networkResponse.data)
        } catch {
            if let logger { await logger.logError(NetworkError.decodingError(error, data: networkResponse.data), for: urlRequest) }
            throw NetworkError.decodingError(error, data: networkResponse.data)
        }
    }

    // MARK: - Private

    private func performRequest(_ urlRequest: URLRequest) async throws -> NetworkResponse {
        var intercepted = urlRequest
        for i in requestInterceptors { intercepted = try await i.intercept(intercepted) }
        if let logger { await logger.logRequest(intercepted) }

        do {
            let (data, response) = try await urlSession.data(for: intercepted)
            var networkResponse = NetworkResponse(data: data, urlResponse: response)
            if let logger { await logger.logResponse(networkResponse, data: data) }

            // Durum kodu eşlemesi yanıt interceptor'larından ÖNCE yapılır.
            // Önceden sıra tersti ve kayıtlı doğrulama interceptor'ı 200..<300
            // dışını genel bir `httpError` olarak fırlattığı için buradaki 429
            // dalına hiç ulaşılmıyordu: sunucunun `Retry-After` başlığı hiç
            // okunmadan atılıyor, yerine sabit üstel geri çekilme kullanılıyordu.
            try validateResponse(networkResponse)

            for i in responseInterceptors { networkResponse = try await i.intercept(networkResponse) }
            return networkResponse
        } catch let error as URLError {
            let ne = mapURLError(error)
            if let logger { await logger.logError(ne, for: intercepted) }
            throw ne
        } catch let ne as NetworkError {
            throw ne
        } catch {
            let ne = NetworkError.networkError(error)
            if let logger { await logger.logError(ne, for: intercepted) }
            throw ne
        }
    }

    nonisolated private func validateResponse(_ response: NetworkResponse) throws {
        switch response.statusCode {
        case 200...299: return
        case 400: throw NetworkError.badRequest()
        case 401: throw NetworkError.unauthorized()
        case 403: throw NetworkError.forbidden()
        case 404: throw NetworkError.notFound()
        case 413: throw NetworkError.requestTooLarge
        case 429:
            throw NetworkError.rateLimited(
                retryAfter: response.header(forKey: "Retry-After").flatMap(TimeInterval.init)
            )
        case 500...599: throw NetworkError.serverError(statusCode: response.statusCode)
        default:
            throw NetworkError.httpError(
                statusCode: response.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
                data: response.data
            )
        }
    }

    nonisolated private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut:                                     return .timeout()
        case .cancelled:                                    return .cancelled
        case .notConnectedToInternet, .networkConnectionLost: return .networkError(error)
        case .cannotFindHost, .cannotConnectToHost:         return .networkError(error)
        case .badURL:                                       return .invalidURL(error.failureURLString)
        default:                                            return .networkError(error)
        }
    }

    private func withRetry<T: Sendable>(
        maxAttempts: Int,
        retryDelay: TimeInterval,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as NetworkError {
                lastError = error
                if !error.isRetryable { throw error }
                if attempt < maxAttempts {
                    // Sunucu ne kadar bekleneceğini söylediyse ona uyulur;
                    // söylemediyse üstel geri çekilme.
                    let backoff = min(retryDelay * pow(2.0, Double(attempt - 1)) * (1 + Double.random(in: 0...0.1)), 30.0)
                    let delay = error.retryAfter ?? backoff
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }
        throw lastError ?? NetworkError.networkError(NSError(domain: "NetworkService", code: -1))
    }
}
