//
//  HomeTab.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import SwiftUI
import NavigatorUI
import FactoryKit
import NetworkKit
import Models

struct HomeTab: View {
    var body: some View {
        ManagedNavigationStack {
            HomeContentView()
        }
    }
}

private struct HomeContentView: View {
    @Environment(\.navigator)
    private var navigator

    @Injected(\.homeService)
    private var service

    var body: some View {
        Button {
            navigator.navigate(to: HomeDestinations.bookDetail)
        } label: {
            Text("Go detail")
        }
        .task {
            let photos = try? await service?.fetchPhotos()
            print(photos ?? [])
        }
    }
}

struct PhotosEndpoint: Endpoint {
    typealias Response = [Photo]
    var path: String = "/photos"
    var queryParameters: [String : String]? = [:]
}

protocol HomeService {
    func fetchPhotos() async throws -> [Photo]
}

final class HomeServiceLive: HomeService {

    @Injected(\.networkService)
    private var networkService

    nonisolated init() {}

    func fetchPhotos() async throws -> [Photo] {
        do {
            return try await networkService.execute(PhotosEndpoint())
        } catch {
            // örn: logger.error("fetchPhotos failed: \(error)")
            throw error
        }
    }
}

extension Container {
    var homeService: Factory<HomeService?> { self { nil } }
}
