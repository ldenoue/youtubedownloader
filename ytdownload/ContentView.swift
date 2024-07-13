//
//  ContentView.swift
//  ytdownload
//
//  Created by Laurent Denoue on 7/13/24.
//

import SwiftUI
import AVKit
struct ContentView: View {
    @State private var link: String = "https://www.youtube.com/watch?v=osKyvYJ3PRM"
    @State private var videoURL: URL?
    @State private var progress: Int = 0
    @State private var downloading: Bool = false
    private var downloader = YoutubeDownloader()
    var body: some View {
        VStack {
            Image("image").resizable().aspectRatio(contentMode: .fit)
            Text("Youtube Downloader").font(.title2)
            Text("made by [@ldenoue](https://twitter.com/ldenoue)").font(.body)
            TextField("Youtube link", text: $link).textFieldStyle(.roundedBorder).padding()
            Button("Download") {
                downloading = true
                Task {
                    await downloader.download(link: link, progress: { p in progress = p}) { destURL in
                        downloading = false
                        videoURL = destURL
                    }
                }
            }.disabled(downloading)
            Text("\(progress)%").padding()
            if let videoURL = videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
            } else {
                Rectangle().fill(Color.black).padding(0)
            }
        }
        .padding(0)
    }
}

#Preview {
    ContentView()
}
