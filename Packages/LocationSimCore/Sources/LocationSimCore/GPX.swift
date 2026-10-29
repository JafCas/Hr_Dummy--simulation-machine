import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct GPXWaypoint: Hashable, Sendable {
    public var coordinate: Coordinate
    public var name: String?
    public var time: Date?

    public init(coordinate: Coordinate, name: String? = nil, time: Date? = nil) {
        self.coordinate = coordinate
        self.name = name
        self.time = time
    }
}

/// Builds GPX 1.1 documents in the format Xcode's "Simulate Location" accepts.
/// One waypoint = static location. Several timestamped waypoints = Xcode moves between them over time.
public enum GPXBuilder {
    public static func document(waypoints: [GPXWaypoint], creator: String = "LocationSimulator") -> String {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="\#(escape(creator))" xmlns="http://www.topografix.com/GPX/1/1">"#
        ]
        for wpt in waypoints {
            let c = wpt.coordinate
            lines.append(#"    <wpt lat="\#(Coordinate.format(c.latitude))" lon="\#(Coordinate.format(c.longitude))">"#)
            if let name = wpt.name { lines.append("        <name>\(escape(name))</name>") }
            if let time = wpt.time { lines.append("        <time>\(timestamp(time))</time>") }
            lines.append("    </wpt>")
        }
        lines.append("</gpx>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Static location, or (with `jitterSamples` > 1) a sequence of points that wander randomly
    /// inside `accuracyRadius` meters to mimic real GPS noise. Every point stays within the radius.
    public static func document<G: RandomNumberGenerator>(
        for location: SimulatedLocation,
        accuracyRadius: Double,
        jitterSamples: Int,
        interval: TimeInterval = 5,
        start: Date = Date(timeIntervalSince1970: 1_700_000_000),
        using generator: inout G
    ) -> String {
        let radius = GeoMath.clampAccuracy(accuracyRadius)
        guard jitterSamples > 1, radius > 0 else {
            return document(waypoints: [GPXWaypoint(coordinate: location.coordinate, name: location.name)])
        }
        var waypoints = [GPXWaypoint(coordinate: location.coordinate, name: location.name, time: start)]
        for i in 1..<jitterSamples {
            let point = GeoMath.randomPoint(around: location.coordinate, within: radius, using: &generator)
            waypoints.append(GPXWaypoint(coordinate: point, name: location.name, time: start.addingTimeInterval(Double(i) * interval)))
        }
        return document(waypoints: waypoints)
    }

    public static func document(for location: SimulatedLocation, accuracyRadius: Double = 0, jitterSamples: Int = 1) -> String {
        var generator = SystemRandomNumberGenerator()
        return document(for: location, accuracyRadius: accuracyRadius, jitterSamples: jitterSamples, using: &generator)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func timestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f.string(from: date)
    }
}

public enum GPXParser {
    public static func waypoints(from data: Data) -> [GPXWaypoint] {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        return parser.parse() ? delegate.waypoints : []
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var waypoints: [GPXWaypoint] = []
        private var current: GPXWaypoint?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            text = ""
            if name == "wpt", let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init) {
                current = GPXWaypoint(coordinate: Coordinate(latitude: lat, longitude: lon))
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name {
            case "name": current?.name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            case "wpt":
                if let wpt = current { waypoints.append(wpt) }
                current = nil
            default: break
            }
        }
    }
}
