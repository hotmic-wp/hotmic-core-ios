import SwiftUI
import HotMicCore

struct StreamsView: View {
    @State private var model = StreamsModel(
        apiKey: HotMicCoreExampleApp.defaultAPIKey,
        accessToken: HotMicCoreExampleApp.defaultAccessToken
    )
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.streams.isEmpty {
                    ProgressView("Loading streams…")
                } else if model.streams.isEmpty {
                    ContentUnavailableView {
                        Text(model.needsCredentials ? "Add Credentials" : "No Streams")
                    } description: {
                        Text(model.needsCredentials
                            ? "Enter your API key and access token in Settings."
                            : model.errorMessage ?? "There are no streams available right now.")
                    } actions: {
                        if model.needsCredentials {
                            Button("Open Settings") { isShowingSettings = true }
                        } else {
                            Button("Try Again") {
                                Task { await model.refresh() }
                            }
                        }
                    }
                } else {
                    StreamsList(model: model)
                }
            }
            .navigationTitle("HotMicCore Example")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gear") {
                        isShowingSettings = true
                    }
                    .disabled(model.isLoading)
                    .sheet(isPresented: $isShowingSettings) {
                        SettingsView(model: model)
                    }
                }
            }
            .task {
                await model.refresh()
            }
        }
    }
}

private struct StreamsList: View {
    let model: StreamsModel
    
    var body: some View {
        List {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            ForEach(model.streams, id: \.id) { stream in
                NavigationLink {
                    StreamSessionView(
                        client: model.client,
                        streamID: stream.id,
                        title: stream.title
                    )
                } label: {
                    StreamRow(stream: stream)
                }
            }

            if model.hasNextPage {
                Button {
                    Task { await model.loadNextPage() }
                } label: {
                    HStack {
                        Spacer()
                        if model.isLoading {
                            ProgressView()
                        } else {
                            Text("Load More")
                        }
                        Spacer()
                    }
                }
                .foregroundStyle(Color.accentColor)
                .disabled(model.isLoading)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await model.refresh()
        }
    }
}

private struct StreamRow: View {
    let stream: HotMicStreamSummary

    var body: some View {
        HStack(spacing: 15) {
            AsyncImage(url: stream.thumbnail) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Color.secondary.opacity(0.15)
                    Image(systemName: "play.rectangle.fill")
                }
            }
            .frame(width: 112, height: 112 / (16 / 9))
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(stream.title ?? "Untitled Stream")
                    .font(.headline)
                    .lineLimit(3)

                Text(stream.user.displayName ?? "Host")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(stream.state.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(stream.state.tint)

                    if stream.viewers > 0 {
                        Label("\(stream.viewers)", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private extension HotMicStream.State {
    var displayName: String {
        switch self {
        case .live: "LIVE"
        case .scheduled: "SCHEDULED"
        case .vod: "REPLAY"
        case .ended: "ENDED"
        default: rawValue
        }
    }

    var tint: Color {
        switch self {
        case .live: .red
        case .scheduled: .orange
        case .vod: .purple
        default: .secondary
        }
    }
}
