import SwiftUI
import Models

struct BookDetailView: View {
    private let book: BookReference
    @Environment(ViewModelFactory.self) private var viewModelFactory
    @State private var holder = ViewModelHolder<BookDetailViewModel>()

    init(book: BookReference) { self.book = book }

    var body: some View {
        BookDetailContent(viewModel: holder { viewModelFactory.makeBookDetailViewModel(book: book) })
    }
}

private struct BookDetailContent: View {
    @State var viewModel: BookDetailViewModel
    @State private var isDescriptionExpanded = false
    @Environment(AppRouteTypeManager.self) private var routeManager
    private var book: BookReference { viewModel.book }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                BookIdentityHeader(book: book)
                    .background(ReadingStyle.sage.opacity(0.55), in: .rect(cornerRadius: 28))
                if viewModel.isInLibrary {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Already in your library").font(.subheadline.weight(.medium))
                        Spacer(minLength: 0)
                        Button("Library") { routeManager.selectedTab = .books }
                            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }
                    .foregroundStyle(ReadingStyle.accent)
                }
                if let description = book.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ReadingSectionHeading(title: "Inside the book")
                        Text(description)
                            .font(.body).lineSpacing(5)
                            .foregroundStyle(ReadingStyle.secondary)
                            .lineLimit(!isDescriptionExpanded && description.count > 250 ? 6 : nil)
                        if description.count > 250 {
                            Button(isDescriptionExpanded ? "Read less" : "Read more") {
                                isDescriptionExpanded.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                        }
                    }
                }
                if !book.subjects.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ReadingSectionHeading(title: "Subjects")
                        FlowingTags(names: book.subjects)
                    }
                }
                if book.pageCount != nil || book.publicationYear != nil || book.isbn13 != nil {
                    metadata
                }
            }
            .padding(24)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle("Book details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            Button { viewModel.presentForm() } label: {
                Label(viewModel.primaryActionTitle, systemImage: viewModel.isInLibrary ? "pencil" : "plus")
            }
            .buttonStyle(ReadingButtonStyle())
            .padding(.horizontal, 24).padding(.vertical, 12)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
            .background(ReadingStyle.background)
        }
        .sheet(isPresented: $viewModel.isPresentingForm) { AddToLibraryForm(viewModel: viewModel) }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.load() }
        .task { await viewModel.enrich() }
    }

    private var metadata: some View {
        VStack(spacing: 12) {
            if let pageCount = book.pageCount { LabeledContent("Pages", value: String(pageCount)) }
            if let day = book.publicationDay {
                LabeledContent("Published") { Text(day, format: .dateTime.year().month(.abbreviated).day()) }
            } else if let month = book.publicationMonth {
                LabeledContent("Published") { Text(month, format: .dateTime.year().month(.wide)) }
            } else if let year = book.publicationYear {
                LabeledContent("Published", value: year)
            }
            if let isbn = book.isbn13 { LabeledContent("ISBN-13", value: isbn) }
        }
        .font(.subheadline).foregroundStyle(ReadingStyle.secondary)
        .readingCard()
    }
}

private struct AddToLibraryForm: View {
    @Bindable var viewModel: BookDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsCategories = false
    private enum Field { case pageCount, category }
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    BookRowView(title: viewModel.book.title, author: viewModel.book.author,
                                coverURL: viewModel.book.coverURL, subtitle: nil)
                        .padding(.vertical, 6)
                }
                .listRowBackground(ReadingStyle.surface)

                Section {
                    Picker("Reading Status", selection: $viewModel.readingStatus) {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Label(status.titleKey, systemImage: status.systemImage).tag(status)
                        }
                    }
                    Picker("Ownership", selection: $viewModel.ownershipStatus) {
                        ForEach(OwnershipStatus.allCases, id: \.self) { status in
                            Label(status.titleKey, systemImage: status.systemImage).tag(status)
                        }
                    }
                } header: { Text("Make it yours") }
                .listRowBackground(ReadingStyle.surface)

                Section {
                    Picker("Progress Type", selection: $viewModel.progressType) {
                        ForEach(ProgressType.allCases, id: \.self) { type in Text(type.titleKey).tag(type) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Page count") {
                        TextField(viewModel.pageCountPlaceholder, text: $viewModel.pageCountText)
                            .focused($focusedField, equals: .pageCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if !viewModel.canSave {
                        Text("Enter a page count greater than zero.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                } header: { Text("Progress") } footer: {
                    Text("Leave the page count empty to use the book’s published length.")
                }
                .listRowBackground(ReadingStyle.surface)

                Section {
                    DisclosureGroup(isExpanded: $showsCategories) {
                        HStack {
                            TextField("New category", text: $viewModel.newCategoryName)
                                .focused($focusedField, equals: .category)
                                .onSubmit { viewModel.addTypedCategory() }
                                .autocorrectionDisabled().textInputAutocapitalization(.words)
                            Button("Add") { viewModel.addTypedCategory() }
                                .disabled(viewModel.newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        ForEach(viewModel.suggestedCategories) { category in
                            Button { viewModel.toggle(category) } label: {
                                HStack {
                                    Text(category.name).foregroundStyle(ReadingStyle.ink)
                                    Spacer()
                                    Image(systemName: viewModel.isSelected(category) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.isSelected(category) ? ReadingStyle.accent : ReadingStyle.secondary)
                                }
                            }
                            .accessibilityAddTraits(viewModel.isSelected(category) ? [.isSelected] : [])
                        }
                    } label: {
                        LabeledContent("Categories") {
                            Text(viewModel.selectedCategories.count, format: .number)
                        }
                    }
                } footer: { Text("Optional. Give your books a little order with personal tags.") }
                .listRowBackground(ReadingStyle.surface)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .readingBackground()
            .navigationTitle(viewModel.isInLibrary ? "Library Details" : "Add to Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { viewModel.save() } label: {
                    Label(viewModel.primaryActionTitle, systemImage: "checkmark")
                }
                .buttonStyle(ReadingButtonStyle())
                .disabled(!viewModel.canSave)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(ReadingStyle.background)
            }
        }
        .presentationDragIndicator(.visible)
    }

}

/// Reuses the same editor from the personal library, including books with no page count.
struct LibraryDetailsEditor: View {
    let book: BookReference
    @Environment(ViewModelFactory.self) private var factory
    @State private var holder = ViewModelHolder<BookDetailViewModel>()

    var body: some View {
        LibraryDetailsEditorContent(viewModel: holder { factory.makeBookDetailViewModel(book: book) })
    }
}

private struct LibraryDetailsEditorContent: View {
    @State var viewModel: BookDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AddToLibraryForm(viewModel: viewModel)
            .onAppear { viewModel.load(); viewModel.presentForm() }
            .onChange(of: viewModel.didSave) { _, saved in if saved { dismiss() } }
            .errorAlert($viewModel.error)
    }
}
