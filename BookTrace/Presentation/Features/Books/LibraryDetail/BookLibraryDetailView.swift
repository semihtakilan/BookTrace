//
//  BookLibraryDetailView.swift
//  LibraryDetail
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI
import NavigatorUI
import Models

/// Kütüphanedeki bir kitabın detayı.
///
/// Plandaki üç eylem burada toplanır: okuma oturumu başlatmak, okuma durumunu
/// değiştirmek ve sahiplik durumunu değiştirmek.
struct BookLibraryDetailView: View {
    private let entry: LibraryEntry

    @Environment(ViewModelFactory.self) private var viewModelFactory
    @State private var holder = ViewModelHolder<LibraryEntryDetailViewModel>()

    init(entry: LibraryEntry) {
        self.entry = entry
    }

    var body: some View {
        BookLibraryDetailContent(
            viewModel: holder { viewModelFactory.makeLibraryEntryDetailViewModel(entry: entry) }
        )
    }
}

private struct BookLibraryDetailContent: View {
    @State var viewModel: LibraryEntryDetailViewModel

    @Environment(\.navigator) private var navigator
    @Environment(LibraryChangeNotifier.self) private var libraryChangeNotifier
    @Environment(\.locale) private var locale
    @State private var isPresentingProgressEditor = false
    @State private var isConfirmingRemoval = false
    @State private var progressInput = ""
    @State private var isEditingDetails = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var entry: LibraryEntry { viewModel.entry }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                // Başlık tam genişlikte; aşağıdaki bölümler kendi kenar
                // boşluğunu taşıyor.
                VStack(alignment: .leading, spacing: 24) {
                    actionButtons
                    progressSection
                    if !entry.categories.isEmpty { categoriesSection }
                    sessionsSection
                    if let description = entry.book.description, !description.isEmpty {
                        aboutSection(description)
                    }
                    removeButton
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .readingBackground()
        .navigationTitle(entry.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isEditingDetails = true } label: { Image(systemName: "pencil") }
                    .accessibilityLabel("Edit library details")
            }
        }
        .sheet(isPresented: $isEditingDetails) { LibraryDetailsEditor(book: entry.book) }
        .safeAreaInset(edge: .bottom) {
            Button { navigator.navigate(to: BooksDestinations.readingSession(entry)) } label: {
                Label("Start reading", systemImage: "play.fill")
            }
            .buttonStyle(ReadingButtonStyle())
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
            .background(ReadingStyle.background)
        }
        .alert("Update progress", isPresented: $isPresentingProgressEditor) {
            TextField(progressFieldPrompt, text: $progressInput)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") { commitProgress() }
        } message: {
            Text(progressFieldPrompt)
        }
        .confirmationDialog(
            "Remove from library?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { viewModel.remove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reading sessions recorded for this book will also be deleted.")
        }
        .errorAlert($viewModel.error)
        .onAppear { viewModel.reload() }
        // Tam ekran okuma oturumu kapanırken bu ekran "yeniden görünmüş" saymadığı
        // için onAppear tetiklenmiyor; oturum kaydı buradan yakalanır.
        .onChange(of: libraryChangeNotifier.revision) { _, _ in viewModel.reload() }
        .onChange(of: viewModel.wasRemoved) { _, wasRemoved in
            if wasRemoved { navigator.back() }
        }
    }

    // MARK: - Bölümler

    private var header: some View {
        BookHeroHeader(book: entry.book, progress: entry.progressFraction)
            .bookAtmosphere(entry.book)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Menu {
                    Picker("Reading Status", selection: readingStatusBinding) {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Label(status.titleKey, systemImage: status.systemImage).tag(status)
                        }
                    }
                } label: {
                    ActionTile(
                        caption: "Reading Status",
                        value: entry.readingStatus.titleKey,
                        systemImage: entry.readingStatus.systemImage
                    )
                }

                Menu {
                    Picker("Ownership Status", selection: ownershipStatusBinding) {
                        ForEach(OwnershipStatus.allCases, id: \.self) { status in
                            Label(status.titleKey, systemImage: status.systemImage).tag(status)
                        }
                    }
                } label: {
                    ActionTile(
                        caption: "Ownership",
                        value: entry.ownershipStatus.titleKey,
                        systemImage: entry.ownershipStatus.systemImage
                    )
                }
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Progress").font(ReadingStyle.title(.title2))
                Picker("Progress Type", selection: progressTypeBinding) {
                    ForEach(ProgressType.allCases, id: \.self) { type in
                        Text(type.titleKey).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }

            ReadingProgressView(entry: entry)

            Button("Update progress") {
                progressInput = currentProgressInput
                isPresentingProgressEditor = true
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            .disabled(entry.effectivePageCount == nil)
            if entry.effectivePageCount == nil {
                Button("Add a page count") { isEditingDetails = true }
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
        }
        .readingCard()
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReadingSectionHeading(title: "Categories")
            FlowingTags(names: entry.categories.map(\.name))
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reading Sessions").font(ReadingStyle.title(.title2))
                Spacer()
                if !entry.readingSessions.isEmpty {
                    Text("\(DurationFormatter.compact(seconds: entry.totalReadSeconds, locale: locale)) · \(entry.totalPagesRead) pages")
                        .font(.caption)
                        .foregroundStyle(ReadingStyle.secondary)
                }
            }

            if entry.readingSessions.isEmpty {
                Text("No sessions yet. Start Reading Mode to record one — the time estimate gets personal after your first session.")
                    .font(.footnote)
                    .foregroundStyle(ReadingStyle.secondary)
            } else {
                ForEach(entry.readingSessions.reversed()) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.startDate, format: .dateTime.day().month().year().hour().minute())
                                .font(.subheadline)
                            Text("\(session.pagesRead) pages")
                                .font(.caption)
                                .foregroundStyle(ReadingStyle.secondary)
                        }
                        Spacer()
                        Text(DurationFormatter.compact(seconds: session.durationSeconds, locale: locale))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(ReadingStyle.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    Divider()
                }
            }
        }
    }

    private func aboutSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ReadingSectionHeading(title: "Inside the book")
            Text(description).font(.body).lineSpacing(5).foregroundStyle(ReadingStyle.secondary)
        }
    }

    private var removeButton: some View {
        Button(role: .destructive) {
            isConfirmingRemoval = true
        } label: {
            Label("Remove from Library", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    // MARK: - Binding'ler

    private var readingStatusBinding: Binding<ReadingStatus> {
        Binding(get: { entry.readingStatus }, set: { viewModel.update(readingStatus: $0) })
    }

    private var ownershipStatusBinding: Binding<OwnershipStatus> {
        Binding(get: { entry.ownershipStatus }, set: { viewModel.update(ownershipStatus: $0) })
    }

    private var progressTypeBinding: Binding<ProgressType> {
        Binding(get: { entry.progressType }, set: { viewModel.update(progressType: $0) })
    }

    // MARK: - İlerleme girişi

    private var progressFieldPrompt: LocalizedStringKey {
        switch entry.progressType {
        case .pages:      "Current page (0 to \(entry.effectivePageCount ?? 0))"
        case .percentage: "Completed percentage (0 to 100)"
        }
    }

    private var currentProgressInput: String {
        switch entry.progressType {
        case .pages:      String(entry.currentPage)
        case .percentage: String(entry.progressPercentage ?? 0)
        }
    }

    /// Yüzde girişi kayda sayfaya çevrilerek yazılır; ilerleme tek birimde tutulur.
    private func commitProgress() {
        guard let value = Int(progressInput.trimmingCharacters(in: .whitespaces)) else { return }

        switch entry.progressType {
        case .pages:
            viewModel.update(currentPage: value)
        case .percentage:
            guard let total = entry.effectivePageCount else { return }
            let clampedPercentage = min(max(0, value), 100)
            viewModel.update(currentPage: Int((Double(total) * Double(clampedPercentage) / 100).rounded()))
        }
    }
}

private struct ActionTile: View {
    let caption: LocalizedStringKey
    let value: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
            Label(caption, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(ReadingStyle.secondary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.caption2).foregroundStyle(ReadingStyle.secondary)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ReadingStyle.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(ReadingStyle.surface, in: .rect(cornerRadius: 18))
    }
}
