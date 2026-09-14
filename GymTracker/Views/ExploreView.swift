import SwiftUI

struct ExploreView: View {
    @State private var videos: [YouTubeVideo] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var searchText = ""
    @State private var hasLoadedOnce = false
    @Environment(\.openURL) private var openURL

    /// Jeff Nippard's channel ID, resolved from youtube.com/@jeffnippard.
    private let channelID = "UC68TLK0mAEzUyHx5x5k-S1Q"

    private var filteredVideos: [YouTubeVideo] {
        guard !searchText.isEmpty else { return videos }
        return videos.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && videos.isEmpty {
                    ProgressView("Loading videos…")
                } else if let loadError, videos.isEmpty {
                    ContentUnavailableView("Couldn't Load Videos", systemImage: "wifi.slash",
                                            description: Text(loadError))
                } else if filteredVideos.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView("No Videos", systemImage: "play.rectangle")
                    } else {
                        ContentUnavailableView.search
                    }
                } else {
                    List(filteredVideos) { video in
                        Button {
                            if let url = video.watchURL {
                                openURL(url)
                            }
                        } label: {
                            VideoRow(video: video)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search Jeff Nippard videos")
            .task {
                guard !hasLoadedOnce else { return }
                hasLoadedOnce = true
                await loadVideos()
            }
            .refreshable { await loadVideos() }
        }
    }

    private func loadVideos() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        guard let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            videos = YouTubeFeedParser.parse(data: data)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct VideoRow: View {
    let video: YouTubeVideo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: video.thumbnailURL) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(16 / 9, contentMode: .fill)
                } else {
                    Rectangle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(video.publishedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
