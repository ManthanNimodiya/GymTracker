import Foundation

struct YouTubeVideo: Identifiable {
    let id: String
    let title: String
    let publishedAt: Date

    var thumbnailURL: URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }

    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }
}

/// Parses a YouTube channel Atom/RSS feed (`youtube.com/feeds/videos.xml?channel_id=...`).
/// This endpoint is public and needs no API key, but only returns the ~15 most recent uploads.
final class YouTubeFeedParser: NSObject, XMLParserDelegate {
    private var videos: [YouTubeVideo] = []
    private var insideEntry = false
    private var currentText = ""
    private var draftId = ""
    private var draftTitle = ""
    private var draftPublished = ""

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(data: Data) -> [YouTubeVideo] {
        let parser = XMLParser(data: data)
        let delegate = YouTubeFeedParser()
        parser.delegate = delegate
        parser.parse()
        return delegate.videos
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName == "entry" {
            insideEntry = true
            draftId = ""
            draftTitle = ""
            draftPublished = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideEntry {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if insideEntry {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "yt:videoId": draftId = trimmed
            case "title": draftTitle = trimmed
            case "published": draftPublished = trimmed
            default: break
            }
        }
        currentText = ""

        if elementName == "entry" {
            insideEntry = false
            guard !draftId.isEmpty else { return }
            let date = Self.dateFormatter.date(from: draftPublished) ?? .now
            videos.append(YouTubeVideo(id: draftId, title: draftTitle, publishedAt: date))
        }
    }
}
