// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - GPX Track & Waypoint Parser

import Foundation
import CoreLocation

public struct GpxWaypoint: Identifiable, Equatable {
    public let id = UUID()
    public let coordinate: CLLocationCoordinate2D
    public let elevation: Double?
    public let time: Date?
    public let name: String?

    public static func == (lhs: GpxWaypoint, rhs: GpxWaypoint) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

public struct GpxTrack: Identifiable {
    public let id = UUID()
    public let name: String
    public let waypoints: [GpxWaypoint]
    public let totalDistanceMeters: Double

    public init(name: String, waypoints: [GpxWaypoint]) {
        self.name = name
        self.waypoints = waypoints

        var total: Double = 0
        if waypoints.count > 1 {
            for i in 0..<(waypoints.count - 1) {
                let locA = CLLocation(latitude: waypoints[i].coordinate.latitude, longitude: waypoints[i].coordinate.longitude)
                let locB = CLLocation(latitude: waypoints[i+1].coordinate.latitude, longitude: waypoints[i+1].coordinate.longitude)
                total += locA.distance(from: locB)
            }
        }
        self.totalDistanceMeters = total
    }
}

public final class GpxParser: NSObject, XMLParserDelegate {
    private var waypoints = [GpxWaypoint]()
    private var trackName: String = "Imported Route"
    private var currentElement: String = ""
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentText: String = ""

    public static func parse(data: Data) -> GpxTrack? {
        let parser = GpxParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        if xmlParser.parse() {
            return GpxTrack(name: parser.trackName, waypoints: parser.waypoints)
        }
        return nil
    }

    public static func parse(gpxString: String) -> GpxTrack? {
        guard let data = gpxString.data(using: .utf8) else { return nil }
        return parse(data: data)
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "trkpt" || elementName == "wpt" {
            if let latStr = attributeDict["lat"], let lat = Double(latStr),
               let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
            }
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "name" && waypoints.isEmpty {
            trackName = trimmed
        } else if elementName == "ele" {
            currentEle = Double(trimmed)
        } else if elementName == "trkpt" || elementName == "wpt" {
            if let lat = currentLat, let lon = currentLon {
                let wp = GpxWaypoint(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    elevation: currentEle,
                    time: nil,
                    name: nil
                )
                waypoints.append(wp)
            }
            currentLat = nil
            currentLon = nil
            currentEle = nil
        }
    }
}
