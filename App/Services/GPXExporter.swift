import Foundation

enum GPXExporter {
    static var defaultDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("GPXExports", isDirectory: true)
    }

    static func write(_ gpx: String, fileName: String, directory: URL = defaultDirectory) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try Data(gpx.utf8).write(to: url, options: .atomic)
        return url
    }
}
