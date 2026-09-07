//
//  NetworkLoggerTests.swift
//  NetworkKitTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation
import Testing
@testable import NetworkKit

struct NetworkLoggerTests {
    @Test func credentialsAreRemovedBeforeTheURLReachesTheLogSystem() throws {
        let url = try #require(URL(string: "https://user:password@example.com/books?q=Dune&KeY=secret&access_token=token#private-fragment"))
        let redacted = NetworkLogger.redactedURL(url)
        #expect(!redacted.contains("secret"))
        #expect(!redacted.contains("=token"))
        #expect(!redacted.contains("user:"))
        #expect(!redacted.contains("password"))
        #expect(!redacted.contains("private-fragment"))
        let components = try #require(URLComponents(string: redacted))
        #expect(components.queryItems?.first(where: { $0.name == "q" })?.value == "Dune")
        #expect(components.queryItems?.first(where: { $0.name == "KeY" })?.value == "<redacted>")
    }

    @Test(arguments: ["Authorization", "Cookie", "Set-Cookie", "X-API-Key", "api_key", "client_secret"])
    func sensitiveHeaderAndQueryNamesAreRecognized(_ name: String) {
        #expect(NetworkLogger.isCredential(name))
    }
}
