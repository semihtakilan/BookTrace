//
//  EndpointTests.swift
//  NetworkKitTests
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation
import Testing
@testable import NetworkKit

private struct TestEndpoint: Endpoint {
    typealias Response = EmptyResponse

    var path: String
    var queryParameters: [String: String]?
    var baseURL: URL
    var httpMethod: HTTPMethod = .GET
    var httpBody: HTTPBody?

    init(
        path: String,
        queryParameters: [String: String]? = nil,
        baseURL: URL = URL(string: "https://example.com/v1")!,
        httpMethod: HTTPMethod = .GET,
        httpBody: HTTPBody? = nil
    ) {
        self.path = path
        self.queryParameters = queryParameters
        self.baseURL = baseURL
        self.httpMethod = httpMethod
        self.httpBody = httpBody
    }
}

private struct EmptyResponse: Decodable, Sendable {}

struct EndpointTests {

    @Test func thePathIsAppendedToTheBaseURL() throws {
        let request = try TestEndpoint(path: "volumes").urlRequest()

        #expect(request.url?.absoluteString == "https://example.com/v1/volumes")
        #expect(request.httpMethod == "GET")
    }

    @Test func queryParametersAreAppendedAndPercentEncoded() throws {
        let endpoint = TestEndpoint(path: "volumes", queryParameters: ["q": "subject:\"science fiction\""])

        let query = try #require(try endpoint.urlRequest().url?.query)

        // Boşluk ve tırnak, URL'e girmeden önce kodlanmalı.
        #expect(!query.contains(" "))
        #expect(query.contains("q="))
        #expect(query.contains("science"))
    }

    @Test func emptyQueryParametersDoNotAddAQuestionMark() throws {
        let request = try TestEndpoint(path: "volumes", queryParameters: [:]).urlRequest()

        #expect(request.url?.absoluteString == "https://example.com/v1/volumes")
    }

    @Test func aGETRequestCarriesNoBodyEvenWhenOneIsSupplied() throws {
        let endpoint = TestEndpoint(
            path: "volumes",
            httpMethod: .GET,
            httpBody: .json(["ignored": "value"])
        )

        let request = try endpoint.urlRequest()

        #expect(request.httpBody == nil)
        #expect(!HTTPMethod.GET.supportsBody)
    }

    @Test func aPOSTRequestEncodesItsBodyAndSetsTheContentType() throws {
        let endpoint = TestEndpoint(
            path: "volumes",
            httpMethod: .POST,
            httpBody: .json(["title": "Dune"])
        )

        let request = try endpoint.urlRequest()

        #expect(request.httpBody != nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func defaultsAreSafeForARead() {
        let endpoint = TestEndpoint(path: "volumes")

        #expect(endpoint.httpMethod == .GET)
        #expect(!endpoint.requiresAuthentication)
        #expect(endpoint.timeout == 30)
    }
}
