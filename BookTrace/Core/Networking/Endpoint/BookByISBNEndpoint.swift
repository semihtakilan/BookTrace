//
//  BookByISBNEndpoint.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation
import NetworkKit
import Models

struct BookByISBNEndpoint: Endpoint {
    typealias Response = [String: Book]

    var path: String = "/api/books"
    var queryParameters: [String: String]?

    init(isbn: String) {
        self.queryParameters = [
            "bibkeys": "ISBN:\(isbn)",
            "format": "json",
            "jscmd": "data"
        ]
    }
}
