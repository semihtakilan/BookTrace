//
//  SubjectEndpoint.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation
import NetworkKit
import Models

struct SubjectEndpoint: Endpoint {
    typealias Response = SubjectResponse

    var path: String
    var queryParameters: [String: String]?

    init(subject: String, limit: Int = 10) {
        self.path = "/subjects/\(subject).json"
        self.queryParameters = ["limit": "\(limit)"]
    }
}
