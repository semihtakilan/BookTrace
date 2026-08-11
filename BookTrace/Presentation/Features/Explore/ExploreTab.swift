//
//  ExploreTab.swift
//  Explore
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

struct ExploreTab: View {
    @State private var viewModel: ExploreViewModel
    @State private var showingScanner = false
    
    init(viewModel: ExploreViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ManagedNavigationStack {
            ExploreContentView(viewModel: viewModel, showingScanner: $showingScanner)
        }
    }
}

private struct ExploreContentView: View {
    @Bindable var viewModel: ExploreViewModel
    @Binding var showingScanner: Bool
    
    var body: some View {
        Group {
            if viewModel.isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView("Explore Books", systemImage: "magnifyingglass", description: Text("Search by Title, Author, or scan a Barcode."))
            } else {
                List(viewModel.searchResults) { book in
                    HStack(spacing: 16) {
                        RemoteBookCover(url: book.coverURL, width: 60, height: 90, contentMode: .fill, fallbackTitle: book.title, fallbackAuthor: book.author)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Explore")
        .searchable(text: $viewModel.searchText, prompt: "Title, Author or ISBN")
        .task(id: viewModel.searchText) {
            // Debounce logic
            let query = viewModel.searchText
            if query.isEmpty {
                viewModel.searchResults = []
                return
            }
            
            do {
                try await Task.sleep(for: .seconds(0.5))
            } catch {
                return // Task was cancelled because searchText changed
            }
            
            // Only perform search if it hasn't changed during sleep
            if !Task.isCancelled {
                await viewModel.performSearch()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button(action: {
                        // Manual Add Action
                    }) {
                        Image(systemName: "plus")
                    }
                    
                    Button(action: {
                        showingScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            NavigationStack {
                BarcodeScannerView { isbn in
                    showingScanner = false
                    Task {
                        await viewModel.handleBarcodeScan(isbn: isbn)
                    }
                } onError: { error in
                    showingScanner = false
                    viewModel.errorMessage = error.localizedDescription
                }
                .navigationTitle("Scan Barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            showingScanner = false
                        }
                    }
                }
            }
        }
    }
}
