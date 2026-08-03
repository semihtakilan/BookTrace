//
//  SearchEndpoint.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation
import NetworkKit
import Models

struct SearchEndpoint: Endpoint {
    typealias Response = SearchResponse

    var path: String = "/search.json"
    var queryParameters: [String: String]?

    init(query: String, limit: Int = 20) {
        self.queryParameters = [
            "q": query,
            "limit": "\(limit)",
            "fields": "key,title,author_name,cover_i,first_publish_year,isbn"
        ]
    }
}
