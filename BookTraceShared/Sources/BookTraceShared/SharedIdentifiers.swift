//
//  SharedIdentifiers.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Foundation

public enum BookTraceSharedConfiguration {
    public static let appGroupIdentifier = "group.com.semihtakilan.BookTrace"
    public static let cloudKitContainerIdentifier = "iCloud.com.semihtakilan.BookTrace"
    public static let proEntitlementDefaultsKey = "booktrace.pro.enabled"
    public static let proExpirationDefaultsKey = "booktrace.pro.expiration"

    public static func hasWidgetAccess(enabled: Bool, expiration: Date?, now: Date = Date()) -> Bool {
        enabled && (expiration.map { $0 > now } ?? true)
    }
}
