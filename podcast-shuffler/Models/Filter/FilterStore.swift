import Foundation

class FilterStore {
    private struct EncodedYearlyFilter: Codable {
        let years: [Int]
    }

    // MARK: - Static properties

    static let shared = FilterStore(userDefaults: .standard)

    // MARK: - Private properties

    private let userDefaults: UserDefaults

    // MARK: - Init

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    // MARK: - Internal methods

    func filter(for feed: Feed) -> Filter {
        if let data = userDefaults.value(forKey: key(for: feed)) as? Data {
            if let yearlyFilter = EncodedYearlyFilter.decoded(from: data) {
                return YearFilter(feed: feed, years: yearlyFilter.years)
            }
        }

        return DefaultFilter(feed: feed)
    }

    func setFilter(_ filter: Filter, for feed: Feed) {
        let value: Data?
        if let yearFilter = filter as? YearFilter {
            value = EncodedYearlyFilter(years: yearFilter.years).encoded
        } else {
            value = nil
        }

        userDefaults.setValue(value, forKey: key(for: feed))
    }

    func removeFilter(for feed: Feed) {
        userDefaults.setValue(nil, forKey: key(for: feed))
    }

    // MARK: - Private methods

    private func key(for feed: Feed) -> String {
        return "filterStore/\(feed.id)"
    }
}

private extension Decodable {
    static func decoded(from data: Data) -> Self? {
        let decoder = JSONDecoder()
        return try? decoder.decode(Self.self, from: data)
    }
}

private extension Encodable {
    var encoded: Data {
        return try! JSONEncoder().encode(self)
    }
}
