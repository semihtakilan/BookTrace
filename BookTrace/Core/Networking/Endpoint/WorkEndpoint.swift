//
//  WorkEndpoint.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation
import NetworkKit
import Models

struct WorkEndpoint: Endpoint {
    typealias Response = WorkDetail

    var path: String
    var queryParameters: [String: String]?

    init(workKey: String) {
        self.path = "\(workKey).json"
    }
}
