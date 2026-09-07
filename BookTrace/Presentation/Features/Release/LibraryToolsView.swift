//
//  LibraryToolsView.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Models
import SwiftUI
import UniformTypeIdentifiers

struct LibraryToolsView: View {
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlement
    @State private var importing = false
    @State private var preview: LibraryBackup?
    @State private var showPaywall = false
    @State private var exportURL: URL?
    @State private var error: String?
    @State private var importTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                Button("Import Goodreads CSV or JSON backup") { importing = true }
                    .disabled(workspace.isImporting)
                Text("Import is free. Existing books keep their progress and notes; new sessions and quotes are added.")
                    .font(.footnote).foregroundStyle(.secondary)
                if workspace.isImporting {
                    ProgressView {
                        if let progress = workspace.importProgress { Text(verbatim: progress) }
                        else { Text("Importing…") }
                    }
                    Button("Stop import", role: .cancel) { importTask?.cancel() }
                }
                if let summary = workspace.importSummary {
                    VStack(alignment: .leading, spacing: 6) {
                        switch summary.outcome {
                        case .completed: Text("Import completed").font(.headline)
                        case .cancelled: Text("Import stopped").font(.headline)
                        case .failed: Text("Import stopped after an error").font(.headline)
                        }
                        Text("\(summary.addedBooks) books added, \(summary.mergedBooks) merged, \(summary.addedGoals) goals added.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Export your library") {
                Button("Full JSON backup") { export(json: true) }
                Button("Goodreads-compatible CSV") { export(json: false) }
                Text("JSON includes reading sessions, quotes and goals. CSV includes the Goodreads-compatible book fields.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let exportURL { ShareLink("Share export", item: exportURL) }
            }
        }
        .navigationTitle("Library transfer")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .json, .plainText]) { result in
            do { preview = try workspace.decodeImport(result.get()) }
            catch { self.error = error.localizedDescription }
        }
        .confirmationDialog("Import these books?", isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } }), titleVisibility: .visible) {
            Button("Import") {
                guard let backup = preview else { return }
                preview = nil
                importTask = Task { await workspace.importLibrary(backup) }
            }
        } message: {
            Text("\(preview?.entries.count ?? 0) books")
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Library transfer", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
        .errorAlert(Binding(get: { workspace.error }, set: { workspace.error = $0 }))
    }

    private func export(json: Bool) {
        guard entitlement.isPro else { showPaywall = true; return }
        do { exportURL = try workspace.export(json: json) }
        catch { self.error = error.localizedDescription }
    }
}

struct ReadingGoalsView: View {
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlement
    @State private var showEditor = false
    @State private var showPaywall = false
    @State private var editing: ReadingGoal?
    @State private var deleting: ReadingGoal?
    var body: some View {
        List {
            if workspace.goals.isEmpty {
                ContentUnavailableView("A little reading, every day", systemImage: "target", description: Text("Choose a reading goal that fits your life."))
            }
            ForEach(workspace.goals) { goal in
                let progress = GoalProgressCalculator.progress(for: goal, entries: workspace.entries)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(goal.period.title).font(.headline)
                        Spacer()
                        if progress.isComplete { Image(systemName: "checkmark.seal.fill").foregroundStyle(ReadingStyle.accent) }
                        if !goal.isActive { Text("Paused").font(.caption) }
                    }
                    Text("\(progress.value) / \(goal.target)") + Text(" ") + Text(goal.metric.title)
                    ProgressView(value: progress.fraction).tint(ReadingStyle.accent)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { if entitlement.isPro { editing = goal; showEditor = true } else { showPaywall = true } }
                .swipeActions { Button("Delete", role: .destructive) { deleting = goal } }
            }
        }
        .navigationTitle("Reading goals")
        .toolbar { Button("Add goal", systemImage: "plus") {
            if entitlement.isPro { editing = nil; showEditor = true } else { showPaywall = true }
        } }
        .sheet(isPresented: $showEditor) { GoalEditor(goal: editing) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog("Delete goal?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Delete", role: .destructive) { if let deleting { workspace.deleteGoal(deleting) }; deleting = nil }
        }
        .errorAlert(Binding(get: { workspace.error }, set: { workspace.error = $0 }))
    }
}

private struct GoalEditor: View {
    let goal: ReadingGoal?
    @Environment(ReadingWorkspace.self) private var workspace
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(\.dismiss) private var dismiss
    @State private var period: ReadingGoal.Period = .yearly
    @State private var metric: ReadingGoal.Metric = .books
    @State private var target = "12"
    @State private var active = true
    var body: some View {
        NavigationStack {
            Form {
                Picker("Period", selection: $period) { ForEach(ReadingGoal.Period.allCases, id: \.self) { Text($0.title).tag($0) } }
                Picker("Measure", selection: $metric) { ForEach(ReadingGoal.Metric.allCases, id: \.self) { Text($0.title).tag($0) } }
                TextField("Target", text: $target).keyboardType(.numberPad)
                Toggle("Active goal", isOn: $active)
                Text("Progress starts when the goal is created and resets with each calendar period.").font(.footnote)
            }
            .navigationTitle(goal == nil ? LocalizedStringKey("New goal") : LocalizedStringKey("Edit goal"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard entitlement.isPro, let amount = Int(target), amount > 0 else { return }
                    workspace.saveGoal(ReadingGoal(id: goal?.id ?? UUID().uuidString, period: period, metric: metric,
                                                  target: amount, startDate: goal?.startDate ?? Date(), isActive: active))
                    if workspace.error == nil { dismiss() }
                }.disabled((Int(target) ?? 0) <= 0 || !entitlement.isPro) }
            }
            .onAppear { if let goal { period = goal.period; metric = goal.metric; target = String(goal.target); active = goal.isActive } }
        }
    }
}

extension ReadingGoal.Period {
    var title: LocalizedStringKey {
        switch self { case .daily: "Daily"; case .weekly: "Weekly"; case .monthly: "Monthly"; case .yearly: "Yearly" }
    }
}
extension ReadingGoal.Metric {
    var title: LocalizedStringKey {
        switch self { case .minutes: "Minutes"; case .pages: "Pages"; case .books: "Books"; case .sessions: "Sessions" }
    }
}
