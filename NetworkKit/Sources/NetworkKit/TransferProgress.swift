//
//  TransferProgress.swift
//  NetworkKit
//
//  Created by Semih TAKILAN on 29.07.2026.
//

import Foundation

/// Yükleme/indirme ilerlemesi; `NetworkService`'in ilerleme geri çağrılarında taşınır.
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
