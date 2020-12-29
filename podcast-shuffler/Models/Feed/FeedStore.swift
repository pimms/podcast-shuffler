import Foundation

import SwiftUI

class FeedStore: ObservableObject {
    static let testStore = FeedStore(feeds: Feed.testData)

    // MARK: - Internal properties

    @Published var feeds: [Feed]

    // MARK: - Private properties

    private lazy var log = Log(self)
    private let feedCache = FeedCache()
    private let httpClient = HttpClient()

    // MARK: - Init

    init(feeds: [Feed]) {
        self.feeds = feeds
    }

    init() {
        self.feeds = []
        loadCachedFeeds()
    }

    // MARK: - Internal methods

    func addFeed(from url: URL, then completion: ((Bool) -> Void)? = nil) {
        log.debug("Adding feed '\(url.absoluteString)'")
        if let id = ITunesIdExtractor().extractId(from: url) {
            log.debug("iTunes link with ID \(id)")
            let linkExtractor = ITunesLinkExtractor(httpClient: httpClient)
            linkExtractor.extractLink(forId: id) { result in
                switch result {
                case .success(let itunesUrl):
                    self.log.debug("Extracted iTunes URL '\(itunesUrl.absoluteString)'")
                    self.addRssFeed(from: itunesUrl, then: completion)
                case .failure:
                    self.log.error("Failed to extract iTunes URL")
                    completion?(false)
                }
            }
        } else {
            addRssFeed(from: url, then: completion)
        }
    }

    func deleteFeed(_ feed: Feed) {
        feedCache.cache
            .filter { $0.feedUrl == feed.url }
            .forEach { feedCache.remove($0) }

        DispatchQueue.syncOnMain {
            feeds = feeds.filter { $0.id != feed.id }
        }
    }

    // MARK: - Private methods

    private func loadCachedFeeds() {
        feedCache.cache.forEach { cacheEntry in
            guard let data = cacheEntry.feedContent,
                  let feed = FeedParser.parseRssData(data, url: cacheEntry.feedUrl) else {
                feedCache.remove(cacheEntry)
                return
            }

            DispatchQueue.main.async {
                self.feeds.append(feed)
            }
        }
    }

    private func addRssFeed(from url: URL, then completion: ((Bool) -> Void)?) {
        guard feedCache.cache.filter({ $0.feedUrl == url }).isEmpty else {
            log.debug("Feed '\(url.absoluteString)' already exists in cache")
            completion?(true)
            return
        }

        httpClient.get(url) { [weak self] response in
            switch response {
            case .success(let data):
                guard let data = data,
                      let feed = FeedParser.parseRssData(data, url: url) else {
                    DispatchQueue.main.async {
                        completion?(false)
                    }
                    return
                }

                self?.feedCache.cacheFeed(url, feedContent: data)
                DispatchQueue.main.async {
                    self?.feeds.append(feed)
                    completion?(true)
                }
            case .failure:
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }
}