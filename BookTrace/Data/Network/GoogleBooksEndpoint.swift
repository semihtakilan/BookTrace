//
//  GoogleBooksEndpoint.swift
//  BookTrace
//

import Foundation
import Models
import NetworkKit

private let googleBooksBaseURL = URL(string: "https://www.googleapis.com/books/v1")!

struct GoogleBooksSearchEndpoint: Endpoint {
    typealias Response = BookSearchResult

    var path: String = "volumes"
    var queryParameters: [String: String]?
    var baseURL: URL { googleBooksBaseURL }

    init(query: String, maxResults: Int = 20, apiKey: String) {
        queryParameters = [
            "q": query,
            "maxResults": String(min(maxResults, 40)),
            "printType": "books",
            "key": apiKey
        ]
    }
}
