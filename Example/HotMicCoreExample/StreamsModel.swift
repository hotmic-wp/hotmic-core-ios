import Foundation
import Observation
import HotMicCore

@MainActor
@Observable
final class StreamsModel {
    enum Filter: String, CaseIterable, Identifiable {
        case all, live, scheduled, vod

        var id: Self { self }
        var title: String {
            switch self {
            case .all: "All"
            case .live: "Live"
            case .scheduled: "Soon"
            case .vod: "Replay"
            }
        }
    }

    private(set) var client: HotMicClient
    private(set) var apiKey: String
    private(set) var accessToken: String

    private(set) var streams: [HotMicStreamSummary] = []
    private(set) var pagination: HotMicStreamPage.Pagination?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var filter: Filter = .all

    var hasNextPage: Bool {
        pagination?.hasNext == true
    }

    init(apiKey: String, accessToken: String) {
        self.apiKey = apiKey
        self.accessToken = accessToken
        client = Self.makeClient(apiKey: apiKey, accessToken: accessToken)
    }

    func refresh() async {
        await load(page: 1, replacing: true)
    }

    func loadNextPage() async {
        guard let pagination, pagination.hasNext else { return }
        await load(page: pagination.currentPage + 1, replacing: false)
    }

    func updateCredentials(apiKey: String, accessToken: String) async {
        guard apiKey != self.apiKey || accessToken != self.accessToken else { return }

        self.apiKey = apiKey
        self.accessToken = accessToken
        client = Self.makeClient(apiKey: apiKey, accessToken: accessToken)
        streams = []
        pagination = nil
        errorMessage = nil
        await load(page: 1, replacing: true)
    }

    private func load(page: Int, replacing: Bool) async {
        guard !isLoading else { return }
        guard !apiKey.isEmpty, !accessToken.isEmpty else {
            errorMessage = "Add an API key and access token in Settings."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await client.fetchStreams(
                matching: HotMicStreamQuery(
                    includesLive: filter == .all || filter == .live,
                    includesScheduled: filter == .all || filter == .scheduled,
                    includesVOD: filter == .all || filter == .vod,
                    page: page,
                    limit: 10
                )
            )

            if replacing {
                streams = result.streams
            } else {
                streams.append(contentsOf: result.streams)
            }
            pagination = result.pagination
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeClient(apiKey: String, accessToken: String) -> HotMicClient {
        HotMicClient(
            apiKey: apiKey,
            accessToken: accessToken,
            logLevel: .error
        )
    }
}
