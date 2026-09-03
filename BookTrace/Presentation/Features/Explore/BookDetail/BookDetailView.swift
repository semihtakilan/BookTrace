//
//  BookDetailView.swift
//  BookDetail
//
//  Created by Semih TAKILAN on 06.08.2026.
//

import SwiftUI
import Models

/// Uzak bir kitabın detayı. Arama, kategori rafı ve barkod akışlarının hepsi buraya çıkar.
struct BookDetailView: View {
    private let book: BookReference

    @Environment(ViewModelFactory.self) private var viewModelFactory
    @State private var holder = ViewModelHolder<BookDetailViewModel>()

    init(book: BookReference) {
        self.book = book
    }

    var body: some View {
        BookDetailContent(
            viewModel: holder { viewModelFactory.makeBookDetailViewModel(book: book) }
        )
    }
}

private struct BookDetailContent: View {
    @State var viewModel: BookDetailViewModel

    private var book: BookReference { viewModel.book }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if viewModel.isInLibrary { inLibraryBadge }
                addToLibraryButton
                metadata
                if !book.subjects.isEmpty { subjectsSection }
                if let description = book.description, !description.isEmpty {
                    aboutSection(description)
                }
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isPresentingForm) {
            AddToLibraryForm(viewModel: viewModel)
        }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            RemoteBookCover(
                url: book.coverURL,
                width: 120,
                height: 180,
                contentMode: .fill,
                fallbackTitle: book.title,
                fallbackAuthor: book.author
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.title3.bold())

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let year = book.publicationYear {
                    Text(year).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var inLibraryBadge: some View {
        Label("Already in your library", systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.green)
    }

    private var addToLibraryButton: some View {
        Button {
            viewModel.presentForm()
        } label: {
            Label(viewModel.primaryActionTitle, systemImage: viewModel.isInLibrary ? "pencil" : "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pageCount = book.pageCount {
                LabeledContent("Pages", value: String(pageCount))
            }
            if let publishedDate = book.publishedDate {
                LabeledContent("Published", value: publishedDate)
            }
            if let isbn13 = book.isbn13 {
                LabeledContent("ISBN-13", value: isbn13)
            }
        }
        .font(.subheadline)
    }

    private var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subjects").font(.headline)
            FlowingTags(names: book.subjects)
        }
    }

    private func aboutSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About").font(.headline)
            Text(description).font(.body)
        }
    }
}

/// Plandaki "Add to Library" akışı: okuma durumu, ilerleme tipi, sayfa sayısı,
/// sahiplik ve kullanıcı etiketleri tek formda toplanır.
private struct AddToLibraryForm: View {
    @Bindable var viewModel: BookDetailViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading Status") {
                    Picker("Reading Status", selection: $viewModel.readingStatus) {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Label(status.titleKey, systemImage: status.systemImage).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("Progress Type", selection: $viewModel.progressType) {
                        ForEach(ProgressType.allCases, id: \.self) { type in
                            Text(type.titleKey).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Page count") {
                        TextField(viewModel.pageCountPlaceholder, text: $viewModel.pageCountText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Progress")
                } footer: {
                    Text("The page count drives your progress bar and the estimated time left. Leave it empty to use the count Google Books reports.")
                }

                Section("Ownership Status") {
                    Picker("Ownership Status", selection: $viewModel.ownershipStatus) {
                        ForEach(OwnershipStatus.allCases, id: \.self) { status in
                            Label(status.titleKey, systemImage: status.systemImage).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Categories") {
                    HStack {
                        TextField("New category", text: $viewModel.newCategoryName)
                            .onSubmit { viewModel.addTypedCategory() }
                        Button("Add") { viewModel.addTypedCategory() }
                            .disabled(viewModel.newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    ForEach(viewModel.suggestedCategories) { category in
                        Button {
                            viewModel.toggle(category)
                        } label: {
                            HStack {
                                Text(category.name).foregroundStyle(.primary)
                                Spacer()
                                if viewModel.isSelected(category) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(viewModel.primaryActionTitle) { viewModel.save() }
                        .disabled(!viewModel.canSave)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(viewModel.isInLibrary ? "Library Details" : "Add to Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
