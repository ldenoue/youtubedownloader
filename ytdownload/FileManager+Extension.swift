//
//  FileManager+Extension.swift
//  ytdownload
//
//  Created by Laurent Denoue on 7/13/24.
//

import Foundation

extension FileManager {
    func merge(files: [URL], to destination: URL, chunkSize: Int = 1000000) {
        //print("FileManager.merge files=",files)
        FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil)
        //try? FileManager.default.removeItem(at: destination)
        guard let writer = try? FileHandle(forWritingTo: destination) else { return }
        files.forEach({ partLocation in
            if let reader = try? FileHandle(forReadingFrom: partLocation) {
                var data = reader.readData(ofLength: chunkSize)
                while data.count > 0 {
                    writer.write(data)
                    data = reader.readData(ofLength: chunkSize)
                }
                reader.closeFile()
            }
        })
        writer.closeFile()
        files.forEach({ file in
            try? FileManager.default.removeItem(at: file)
        })
    }
    
    func getTempURL() -> URL? {
        let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return documentsURL
    }
}
