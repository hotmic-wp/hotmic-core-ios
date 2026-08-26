import SwiftUI
import AVKit
import HotMicCore

struct StreamVideoPlayerView: View {
    let stream: HotMicStream?

    @State private var model = StreamVideoPlayerModel()

    var body: some View {
        ZStack {
            Color.black

            if model.sourceURL != nil {
                VideoPlayer(player: model.player)
            } else {
                AsyncImage(url: stream?.state == .ended ? stream?.endThumbnail : stream?.thumbnail) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.black
                }

                Text(model.unavailableMessage)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 8))
            }
        }
        .aspectRatio(stream?.videoOrientation == .portrait ? 9 / 16 : 16 / 9, contentMode: .fit)
        .onChange(of: stream, initial: true) { _, stream in
            model.update(stream: stream)
        }
        .onDisappear {
            model.stop()
        }
    }
}
