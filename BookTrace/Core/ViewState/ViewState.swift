//
//  ViewState.swift
//  ViewState
//
//  Created by Semih TAKILAN on 03.08.2026.
//

import Foundation

/// Ağdan beslenen bir ekran parçasının dört olası hâli.
enum ViewState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

extension ViewState where Value: Collection {
    /// Yüklenmiş ama boş dönen sonucu, henüz yüklenmemiş olandan ayırmak için.
    var isEmptyResult: Bool {
        guard case .loaded(let value) = self else { return false }
        return value.isEmpty
    }
}
