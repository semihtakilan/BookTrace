//
//  ViewState.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation

enum ViewState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}
