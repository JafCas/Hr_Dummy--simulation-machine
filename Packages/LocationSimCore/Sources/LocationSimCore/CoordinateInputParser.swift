import Foundation

/// Parses user input into a coordinate: plain "lat, lon" text or Google Maps URLs.
public enum CoordinateInputParser {
    public enum Result: Equatable, Sendable {
        case coordinate(Coordinate)
        /// A short link (maps.app.goo.gl / goo.gl/maps) that must be resolved over the network first.
        case shortLink(URL)
    }

    public static func parse(_ input: String) -> Result? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), let host = url.host?.lowercased() {
            if host == "maps.app.goo.gl" || (host == "goo.gl" && url.path.hasPrefix("/maps")) {
                return .shortLink(url)
            }
            return coordinate(fromGoogleMapsURL: text).map(Result.coordinate)
        }
        return plainCoordinate(text).map(Result.coordinate)
    }

    /// "19.432608, -99.133209", "19.432608 -99.133209" or "19.432608;-99.133209".
    public static func plainCoordinate(_ text: String) -> Coordinate? {
        let pattern = #"^\s*(-?\d{1,2}(?:\.\d+)?)\s*[,; ]\s*(-?\d{1,3}(?:\.\d+)?)\s*$"#
        guard let m = firstMatch(pattern, in: text) else { return nil }
        return validated(m.0, m.1)
    }

    /// Extracts the place coordinate from a Google Maps URL. Priority:
    /// `!3d<lat>!4d<lon>` (exact place pin) > `q=`/`query=`/`ll=`/`destination=` > `@lat,lon` (viewport center).
    public static func coordinate(fromGoogleMapsURL urlString: String) -> Coordinate? {
        let decoded = urlString.removingPercentEncoding ?? urlString
        let number = #"(-?\d{1,3}\.\d+)"#
        let patterns = [
            #"!3d\#(number)!4d\#(number)"#,
            #"[?&](?:q|query|ll|destination|center)=(?:loc:)?\#(number)\s*,\s*\#(number)"#,
            #"@\#(number),\#(number)"#
        ]
        for pattern in patterns {
            if let m = firstMatch(pattern, in: decoded), let c = validated(m.0, m.1) {
                return c
            }
        }
        return nil
    }

    private static func validated(_ lat: String, _ lon: String) -> Coordinate? {
        guard let la = Double(lat), let lo = Double(lon) else { return nil }
        let c = Coordinate(latitude: la, longitude: lo)
        return c.isValid ? c : nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let r1 = Range(match.range(at: 1), in: text),
              let r2 = Range(match.range(at: 2), in: text)
        else { return nil }
        return (String(text[r1]), String(text[r2]))
    }
}
