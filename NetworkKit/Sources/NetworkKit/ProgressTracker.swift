import Foundation

// MARK: - Progress Tracker

public actor ProgressTracker {
    public typealias ProgressHandler = @Sendable (Double) -> Void
    private var handlers: [UUID: ProgressHandler] = [:]

    public init() {}

    public func addProgressHandler(_ handler: @escaping ProgressHandler) -> UUID {
        let id = UUID()
        handlers[id] = handler
        return id
    }

    public func removeProgressHandler(id: UUID) { handlers.removeValue(forKey: id) }

    public func updateProgress(_ progress: Double) {
        handlers.values.forEach { $0(progress) }
    }
}

// MARK: - Transfer Progress

public struct TransferProgress: Sendable {
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesTransferred) / Double(totalBytes)
    }

    public init(bytesTransferred: Int64, totalBytes: Int64) {
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
    }
}
