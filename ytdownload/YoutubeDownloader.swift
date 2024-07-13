//
//  YoutubeDownloader.swift
//  ytdownload
//
//  Created by Laurent Denoue on 7/13/24.
//

import Foundation
import Alamofire
import YouTubeKit
import AVKit

let USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.101 Safari/537.36"

class YoutubeDownloader {
    
    func download(link: String, progress: @escaping (_ progress: Int) -> (), completionHandler: @escaping (_ url: URL?) -> ()) async {
        guard let url = URL(string: link) else {
            print("not a valid link")
            completionHandler(nil)
            return
        }
        let video = YouTube(url: url)
        guard let streams = try? await video.streams else {
            print("no streams")
            return completionHandler(nil)
        }
        let audioVideoStream = streams.filterVideoAndAudio().filter { $0.isNativelyPlayable }.first
        if let audioVideoStream = audioVideoStream {
            fetchContentLength(for: audioVideoStream.url, completionHandler: { (contentLength) in
                if let contentLength = contentLength, contentLength > 0 {
                    self.downloadNow(url: audioVideoStream.url, fileSize: Int64(contentLength), videoId: video.videoID, progress: progress, completionHandler: completionHandler)
                } else {
                    completionHandler(nil)
                }
            })
        } else {
            completionHandler(nil)
        }
    }

    private func fetchContentLength(for url: URL, completionHandler: @escaping (_ contentLength: UInt64?) -> ()) {
      var request = URLRequest(url: url)
      request.httpMethod = "HEAD"
      request.addValue(USER_AGENT, forHTTPHeaderField: "User-Agent")
      let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        guard error == nil,
          let response = response as? HTTPURLResponse,
          let contentLength = response.allHeaderFields["Content-Length"] as? String else {
            completionHandler(nil)
            return
        }
        completionHandler(UInt64(contentLength))
      }
        
      task.resume()
    }

    private func downloadNow(url: URL, fileSize: Int64, videoId: String, progress: @escaping (_ progress: Int) -> (), completionHandler: @escaping (_ url: URL?) -> ()) {
        if fileSize == 0 {
            completionHandler(nil)
            return
        }
        guard let documentsURL = FileManager.default.getTempURL() else { return }
        var chunkLen: Int64 = fileSize / 20
        if chunkLen < 1024 * 1024 * 2 {
            chunkLen = 1024 * 1024 * 2
        }
        let nChunks: Int = Int(fileSize / chunkLen + 1)
        var startByte: Int64 = 0
        var nDone = 0
        var fileURLs = [URL]()
        let filename = videoId + "-video.mp4"
        let destURL = documentsURL.appendingPathComponent(filename)
        var fractionsCompleted = [CGFloat]()
        for c in 0..<nChunks {
            let name = "video-\(c).mp4"
            let fileURL = documentsURL.appendingPathComponent(name)
            fileURLs.append(fileURL)
            fractionsCompleted.append(0)
            var endByte: Int64 = startByte + chunkLen - 1
            if endByte > fileSize - 1 {
                endByte = fileSize - 1
            }
            if endByte - startByte <= 0 {
                nDone += 1
            } else {
                let headers: HTTPHeaders = [
                    "User-Agent": USER_AGENT,
                    "Range": "bytes=\(startByte)-\(endByte)",
                    "cnt": "\(c)"
                ]
                startByte += chunkLen
                let destination: DownloadRequest.Destination = { _, _ in
                    return (fileURLs[c], [.removePreviousFile])
                }
                AF.download(url.absoluteString, headers: headers, to: destination)
                    .downloadProgress { p in
                        let fractionCompleted = p.fractionCompleted
                        if let cnt = headers.value(for: "cnt"), let c = Int(cnt) {
                            fractionsCompleted[c] = fractionCompleted
                        }
                        var total = 0.0
                        for i in 0..<nChunks {
                            total += fractionsCompleted[i]
                        }
                        total /= CGFloat(nChunks)
                        let percent = Int(total * 100)
                        progress(percent)
                    }
                    .responseData { response in
                        switch response.result {
                        case .success:
                            nDone += 1
                            if nDone == nChunks {
                                FileManager.default.merge(files: fileURLs, to: destURL)
                                completionHandler(destURL)
                            }
                        case .failure(let error):
                            print("Error:", error,nDone,nChunks)
                        }
                    }
            }
        }
    }
}
