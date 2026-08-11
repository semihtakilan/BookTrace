//
//  ViewState.swift
//  ViewState
//
//  Created by Semih TAKILAN on 03.08.2026.
//

import Foundation

enum ViewState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}
