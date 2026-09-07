//
//  CloudSyncStatus.swift
//  Sync
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import BookTraceShared
import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CloudSyncStatus {
    enum State { case local, checking, unavailable, syncing, ready, failed }
    private(set) var state: State = .local
    private(set) var lastSync: Date?
    private(set) var message: String?
    private let cloudEnabled: Bool
    private let sharingAvailable: Bool
    private let context: ModelContext
    private let notifier: LibraryChangeNotifier
    @ObservationIgnored nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init(cloudEnabled: Bool, sharingAvailable: Bool, context: ModelContext, notifier: LibraryChangeNotifier) {
        self.cloudEnabled = cloudEnabled; self.sharingAvailable = sharingAvailable
        self.context = context; self.notifier = notifier
    }

    func start() async {
        if observers.isEmpty {
            observers.append(NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.importedChanges() }
            })
            observers.append(NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
                let ended = event.endDate
                let error = event.error?.localizedDescription
                let imported = event.type == .import
                Task { @MainActor in
                    guard let self else { return }
                    if let error { self.state = .failed; self.message = error }
                    else if let ended {
                        self.state = .ready; self.lastSync = ended; self.message = nil
                        if imported { self.importedChanges() }
                    } else { self.state = .syncing }
                }
            })
        }
        await refresh()
    }

    func refresh() async {
        guard sharingAvailable && cloudEnabled else { state = .local; return }
        state = .checking
        do {
            let status = try await CKContainer(identifier: LocalStore.cloudContainerIdentifier).accountStatus()
            guard status == .available else { state = .unavailable; return }
            state = cloudEnabled ? .ready : .local
        } catch { state = .failed; message = error.localizedDescription }
    }

    private func importedChanges() {
        do {
            try LibraryDeduplicator.run(in: context)
            notifier.notifyChanged()
        } catch { state = .failed; message = error.localizedDescription }
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}
