import Foundation
import Testing
@testable import NetworkKit

struct ExpiringMemoryCacheTests {
    @Test func returnsCachedValueBeforeExpiry() {
        let cache = ExpiringMemoryCache<String>(timeToLive: 60)
        cache.insert("cached", for: "books:swift")

        #expect(cache.value(for: "books:swift") == "cached")
    }

    @Test func evictsExpiredValue() {
        let clock = TestClock(date: Date(timeIntervalSince1970: 0))
        let cache = ExpiringMemoryCache<String>(timeToLive: 60) { clock.date }
        cache.insert("cached", for: "books:swift")
        clock.date = clock.date.addingTimeInterval(61)

        #expect(cache.value(for: "books:swift") == nil)
    }
}

private final class TestClock: @unchecked Sendable {
    var date: Date

    init(date: Date) {
        self.date = date
    }
}
