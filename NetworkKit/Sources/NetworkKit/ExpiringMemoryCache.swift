import Foundation

/// Thread-safe, TTL-aware in-memory cache backed by `NSCache`.
public final class ExpiringMemoryCache<Value: Sendable>: @unchecked Sendable {
    private final class Entry: NSObject {
        let value: Value
        let expiryDate: Date

        init(value: Value, expiryDate: Date) {
            self.value = value
            self.expiryDate = expiryDate
        }
    }

    private let cache = NSCache<NSString, Entry>()
    private let timeToLive: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        timeToLive: TimeInterval,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.timeToLive = max(0, timeToLive)
        self.now = now
    }

    public func value(for key: String) -> Value? {
        let cacheKey = key as NSString
        guard let entry = cache.object(forKey: cacheKey) else { return nil }
        guard entry.expiryDate > now() else {
            cache.removeObject(forKey: cacheKey)
            return nil
        }
        return entry.value
    }

    public func insert(_ value: Value, for key: String) {
        let entry = Entry(value: value, expiryDate: now().addingTimeInterval(timeToLive))
        cache.setObject(entry, forKey: key as NSString)
    }

    public func removeValue(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    public func removeAll() {
        cache.removeAllObjects()
    }
}
