import AVFoundation
import Foundation
import Observation
import HotMicCore

@MainActor
@Observable
final class StreamVideoPlayerModel {
    let player = AVPlayer()

    private(set) var sourceURL: URL?
    private(set) var unavailableMessage = "Loading…"
    private var stream: HotMicStream?

    init() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .moviePlayback)
        try? audioSession.setActive(true)
    }

    func update(stream: HotMicStream?) {
        self.stream = stream
        updateSourceIfNeeded()
    }

    func stop() {
        player.pause()
    }

    private func updateSourceIfNeeded() {
        let selection = playbackSelection()
        unavailableMessage = selection.message

        guard selection.url != sourceURL else { return }
        sourceURL = selection.url
        player.replaceCurrentItem(with: selection.url.map(AVPlayerItem.init(url:)))
        if selection.url != nil {
            player.play()
        }
    }

    private func playbackSelection() -> (url: URL?, message: String) {
        guard let stream else {
            return (nil, "Loading…")
        }
        if stream.state == .ended {
            return (nil, "This stream has ended.")
        }
        if stream.state == .scheduled {
            if let date = stream.scheduledDate {
                return (nil, "This stream starts \(date.formatted(date: .abbreviated, time: .shortened)).")
            } else {
                return (nil, "This stream is scheduled to go live.")
            }
        }
        if stream.state == .vod {
            return (stream.vodURL, "No replay URL available.")
        }
        return (stream.hlsURL, "No live playback URL available.")
    }
}
