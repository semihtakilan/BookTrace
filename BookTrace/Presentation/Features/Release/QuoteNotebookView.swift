//
//  QuoteNotebookView.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import AVFoundation
import Models
import SwiftUI
import VisionKit

struct QuoteNotebookView: View {
    var bookID: String? = nil
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlement
    @State private var search = ""
    @State private var editor: QuoteEditorDraft?
    @State private var deletion: NotebookQuote?
    @State private var sharing: NotebookQuote?
    @State private var showsPaywall = false

    private var rows: [NotebookQuote] {
        workspace.entries.filter { bookID == nil || $0.id == bookID }.flatMap { entry in
            entry.quotes.map { NotebookQuote(book: entry.book, quote: $0) }
        }
        .filter { row in
            search.isEmpty || [row.quote.text, row.quote.note ?? "", row.book.title, row.book.authors.joined(separator: " ")]
                .contains { $0.localizedCaseInsensitiveContains(search) }
        }
        .sorted { $0.quote.createdDate > $1.quote.createdDate }
    }

    var body: some View {
        List {
            if rows.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? LocalizedStringKey("Keep the words that stay with you") : LocalizedStringKey("No matching quotes"),
                    systemImage: "text.quote",
                    description: Text(search.isEmpty ? LocalizedStringKey("Add a quote by hand or scan a page, then make it your own.") : LocalizedStringKey("Try a different word, note, or book title."))
                )
            }
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 12) {
                    Text(row.quote.text).font(.body).textSelection(.enabled)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.book.title).font(.subheadline.weight(.semibold))
                        if let page = row.quote.pageNumber { Text("Page \(page)").font(.caption) }
                        if let note = row.quote.note, !note.isEmpty {
                            Text(note).font(.subheadline).foregroundStyle(ReadingStyle.secondary)
                        }
                    }
                    HStack(spacing: 20) {
                        Button { mutate(row, requiresPro: true) { $0.isFavorite.toggle() } } label: {
                            Image(systemName: row.quote.isFavorite ? "heart.fill" : "heart")
                                .frame(minWidth: 32, minHeight: 44)
                        }
                        .accessibilityLabel(row.quote.isFavorite ? LocalizedStringKey("Remove favorite quote") : LocalizedStringKey("Favorite quote"))
                        Button("Edit") {
                            guard entitlement.isPro else { showsPaywall = true; return }
                            editor = QuoteEditorDraft(bookID: row.book.id, quote: row.quote)
                        }
                        Spacer()
                        Button {
                            guard entitlement.isPro else { showsPaywall = true; return }
                            sharing = row
                        } label: { Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Share quote card")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 10)
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { deletion = row }
                }
                .contextMenu {
                    Button("Delete quote", role: .destructive) { deletion = row }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .readingBackground()
        .navigationTitle("Quote notebook")
        .searchable(text: $search, prompt: "Search quotes, notes, and books")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard entitlement.isPro else { showsPaywall = true; return }
                    editor = QuoteEditorDraft(bookID: bookID, quote: nil)
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add quote")
                .disabled(workspace.entries.isEmpty)
            }
        }
        .onAppear { workspace.load() }
        .sheet(item: $editor) { QuoteEditorView(draft: $0) }
        .sheet(item: $sharing) { QuoteCardPreview(row: $0) }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
        .confirmationDialog("Delete this quote?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
            Button("Delete quote", role: .destructive) {
                if let deletion {
                    workspace.deleteQuote(bookID: deletion.book.id, quoteID: deletion.quote.id)
                }
                deletion = nil
            }
        } message: { Text("The quote and its note will be removed from your library.") }
        .errorAlert(Binding(get: { workspace.error }, set: { workspace.error = $0 }))
    }

    private func mutate(_ row: NotebookQuote, requiresPro: Bool, update: (inout Quote) -> Void) {
        guard !requiresPro || entitlement.isPro else { showsPaywall = true; return }
        workspace.mutateQuote(bookID: row.book.id, quoteID: row.quote.id, update)
    }
}

private struct NotebookQuote: Identifiable {
    let book: BookReference
    let quote: Quote
    var id: String { "\(book.id)|\(quote.id)" }
}

private struct QuoteEditorDraft: Identifiable {
    let id = UUID()
    let bookID: String?
    let quote: Quote?
}

private struct QuoteEditorView: View {
    let draft: QuoteEditorDraft
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selectedBookID = ""
    @State private var text = ""
    @State private var pageNumber = ""
    @State private var note = ""
    @State private var isFavorite = false
    @State private var showsScanner = false
    @State private var showsPaywall = false
    @State private var isRecognizing = false
    @State private var scanningError: LocalizedStringKey?
    @State private var recognitionTask: Task<Void, Never>?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    Picker("Book", selection: $selectedBookID) {
                        ForEach(workspace.entries) { entry in Text(entry.book.title).tag(entry.id) }
                    }
                    .disabled(draft.quote != nil || draft.bookID != nil)
                }
                Section {
                    TextEditor(text: $text).frame(minHeight: 190)
                        .accessibilityLabel("Quote text")
                    if isRecognizing { ProgressView("Recognizing text on your device…") }
                    Button("Scan a page") { Task { await startScanner() } }
                        .disabled(isRecognizing)
                } header: {
                    Text("Quote")
                } footer: {
                    Text("Review and edit scanned text before saving. Recognition may be less accurate in some languages, including Turkish.")
                }
                Section("Details") {
                    TextField("Page number (optional)", text: $pageNumber).keyboardType(.numberPad)
                    TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(3...8)
                    Toggle("Favorite quote", isOn: $isFavorite)
                }
            }
            .navigationTitle(draft.quote == nil ? LocalizedStringKey("Add quote") : LocalizedStringKey("Edit quote"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedBookID.isEmpty || isRecognizing || !validPage)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                selectedBookID = draft.bookID ?? workspace.entries.first?.id ?? ""
                text = draft.quote?.text ?? ""
                pageNumber = draft.quote?.pageNumber.map(String.init) ?? ""
                note = draft.quote?.note ?? ""
                isFavorite = draft.quote?.isFavorite ?? false
            }
            .onDisappear { recognitionTask?.cancel() }
            .fullScreenCover(isPresented: $showsScanner) {
                QuoteDocumentScanner { result in
                    showsScanner = false
                    switch result {
                    case .success(let pages): recognize(pages)
                    case .failure(let error):
                        if !(error is CancellationError) { scanningError = "The page could not be scanned. Try again or enter the quote by hand." }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .alert("Page scanning", isPresented: Binding(get: { scanningError != nil }, set: { if !$0 { scanningError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(scanningError ?? "") }
            .errorAlert(Binding(get: { workspace.error }, set: { workspace.error = $0 }))
        }
    }

    private var validPage: Bool { pageNumber.isEmpty || Int(pageNumber).map { $0 > 0 } == true }

    private func startScanner() async {
        guard entitlement.isPro else { showsPaywall = true; return }
        guard VNDocumentCameraViewController.isSupported else {
            scanningError = "Page scanning is unavailable on this device. You can still enter quotes by hand."
            return
        }
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard allowed else {
            scanningError = "Allow camera access in iPhone Settings to scan pages, or enter the quote by hand."
            return
        }
        showsScanner = true
    }

    private func recognize(_ pages: [Data]) {
        recognitionTask?.cancel()
        isRecognizing = true
        recognitionTask = Task {
            defer { isRecognizing = false }
            do {
                let recognized = try await OCRTextRecognition().recognize(pages: pages, preferredLanguages: [locale.identifier] + Locale.preferredLanguages)
                try Task.checkCancellation()
                guard !recognized.isEmpty else {
                    scanningError = "No text was recognized. Try a clearer photo or enter the quote by hand."
                    return
                }
                // Existing typed words remain intact. Nothing is persisted until Save.
                text += text.isEmpty ? recognized : "\n\n" + recognized
            } catch is CancellationError {
            } catch { scanningError = "The page could not be scanned. Try again or enter the quote by hand." }
        }
    }

    private func save() {
        guard entitlement.isPro else { showsPaywall = true; return }
        var quote = draft.quote ?? Quote(id: draft.id.uuidString, text: "")
        quote.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        quote.pageNumber = Int(pageNumber)
        quote.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        quote.isFavorite = isFavorite
        if workspace.saveQuote(quote, bookID: selectedBookID, original: draft.quote) { dismiss() }
    }
}

private struct QuoteCardPreview: View {
    let row: NotebookQuote
    @Environment(BookPaletteStore.self) private var palettes
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showsPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                        if entitlement.isPro {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview(Text(row.book.title), image: Image(uiImage: image))) {
                                Label("Share quote card", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(ReadingButtonStyle())
                        } else {
                            Button("Share quote card") { showsPaywall = true }.buttonStyle(ReadingButtonStyle())
                        }
                    } else { ProgressView("Preparing quote card…") }
                }
                .padding(24)
            }
            .readingBackground()
            .navigationTitle("Quote card")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task {
                await palettes.resolve(for: row.book)
                let renderer = ImageRenderer(content: QuoteShareCard(row: row, palette: palettes.palette(for: row.book)))
                renderer.scale = 3
                image = renderer.uiImage
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
        }
    }
}

private struct QuoteShareCard: View {
    let row: NotebookQuote
    let palette: BookPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "quote.opening").font(.system(size: 42, weight: .light))
            Text(row.quote.text).font(.system(size: 23, design: .serif)).lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(palette.accent(.light).opacity(0.25)).frame(height: 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(row.book.title).font(.system(size: 17, weight: .semibold, design: .serif))
                Text(row.book.authors.joined(separator: ", ")).font(.system(size: 13))
                if let page = row.quote.pageNumber { Text("Page \(page)").font(.system(size: 12)) }
            }
            Text("BookTrace").font(.system(size: 13, weight: .medium, design: .serif)).tracking(2)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(palette.accent(.light))
        .padding(36)
        .frame(width: 390, alignment: .leading)
        .background(LinearGradient(colors: [palette.wash(.light), palette.washEdge(.light)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .environment(\.colorScheme, .light)
    }
}
