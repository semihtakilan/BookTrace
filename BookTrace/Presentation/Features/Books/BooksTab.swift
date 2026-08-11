//
//  BooksTab.swift
//  Books
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

struct BooksTab: View {
    @State private var viewModel: BooksViewModel

    init(viewModel: BooksViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ManagedNavigationStack {
            BooksContentView(viewModel: viewModel)
        }
    }
}

private struct BooksContentView: View {
    @Environment(\.navigator) private var navigator
    @Bindable var viewModel: BooksViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let nowReading = viewModel.nowReading {
                    NowReadingSection(book: nowReading)
                }

                if !viewModel.libraryBooks.isEmpty {
                    LibrarySection(libraryBooks: viewModel.libraryBooks)
                }

                if !viewModel.ownershipBooks.isEmpty {
                    OwnershipSection(ownershipBooks: viewModel.ownershipBooks)
                }

                if !viewModel.categoryBooks.isEmpty {
                    CategoriesSection(categoryBooks: viewModel.categoryBooks)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    print("Edit tapped")
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
    }
}

private struct NowReadingSection: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Now Reading")
                .font(.title2.bold())
                .padding(.horizontal)

            HStack(spacing: 16) {
                RemoteBookCover(url: book.coverURL, width: 80, height: 120, contentMode: .fill, fallbackTitle: book.title, fallbackAuthor: book.author)

                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let totalPages = book.pageCount, totalPages > 0 {
                        ProgressView(value: Double(book.currentProgress), total: Double(totalPages))
                            .progressViewStyle(.linear)
                        Text("\(book.currentProgress) / \(totalPages) pages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct LibrarySection: View {
    let libraryBooks: [ReadingStatus: [Book]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Library")
                .font(.title2.bold())
                .padding(.horizontal)
            
            ForEach(ReadingStatus.allCases, id: \.self) { status in
                if let books = libraryBooks[status], !books.isEmpty {
                    VStack(alignment: .leading) {
                        Text(status.rawValue.capitalized)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        BookHorizontalList(books: books)
                    }
                }
            }
        }
    }
}

private struct OwnershipSection: View {
    let ownershipBooks: [OwnershipStatus: [Book]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ownership")
                .font(.title2.bold())
                .padding(.horizontal)
            
            ForEach(OwnershipStatus.allCases, id: \.self) { status in
                if let books = ownershipBooks[status], !books.isEmpty {
                    VStack(alignment: .leading) {
                        Text(status.rawValue.capitalized)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        BookHorizontalList(books: books)
                    }
                }
            }
        }
    }
}

private struct CategoriesSection: View {
    let categoryBooks: [Models.Category: [Book]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title2.bold())
                .padding(.horizontal)
            
            // Sort by category name
            let sortedCategories = Array(categoryBooks.keys).sorted(by: { $0.name < $1.name })
            
            ForEach(sortedCategories) { category in
                if let books = categoryBooks[category], !books.isEmpty {
                    VStack(alignment: .leading) {
                        Text(category.name)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        BookHorizontalList(books: books)
                    }
                }
            }
        }
    }
}

private struct BookHorizontalList: View {
    let books: [Book]
    @Environment(\.navigator) private var navigator
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(books) { book in
                    Button {
                        navigator.navigate(to: BooksDestinations.bookDetail(book))
                    } label: {
                        BookCoverCell(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct BookCoverCell: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RemoteBookCover(
                url: book.coverURL,
                width: 100,
                height: 150,
                contentMode: .fill,
                fallbackTitle: book.title,
                fallbackAuthor: book.author
            )

            Text(book.title)
                .font(.caption.bold())
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}
