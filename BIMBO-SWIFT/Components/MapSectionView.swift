import CoreLocation
import MapKit
import Observation
import SwiftUI

struct MapSectionView: View {
    let clients: [Client]
    var simulatedStart: CLLocationCoordinate2D? = nil

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var locationManager = LocationManager()
    @State private var routeSegments: [MKRoute] = []

    private var startLocation: CLLocationCoordinate2D? {
        simulatedStart ?? locationManager.currentLocation
    }

    private var orderedClients: [Client] {
        guard let currentLocation = startLocation else { return clients }

        var remainingClients = clients
        var sortedClients: [Client] = []
        var previousCoordinate = currentLocation

        while !remainingClients.isEmpty {
            let nextIndex = remainingClients.enumerated().min { lhs, rhs in
                distance(from: previousCoordinate, to: lhs.element.coordinate)
                    < distance(from: previousCoordinate, to: rhs.element.coordinate)
            }?.offset

            guard let nextIndex else { break }

            let nextClient = remainingClients.remove(at: nextIndex)
            sortedClients.append(nextClient)
            previousCoordinate = nextClient.coordinate
        }

        return sortedClients
    }

    var body: some View {
        ZStack {
            Color.blue

            Map(position: $position) {
                UserAnnotation()

                ForEach(Array(orderedClients.enumerated()), id: \.element.id) { index, client in
                    Annotation(client.name, coordinate: client.coordinate) {
                        VStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(AppColors.accentRed))

                            Text(client.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.primaryBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.92))
                                )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Stop \(index + 1), \(client.name)")
                        .accessibilityValue("Latitude \(client.latitude), longitude \(client.longitude)")
                    }
                }

                ForEach(Array(routeSegments.enumerated()), id: \.offset) { _, route in
                    MapPolyline(route.polyline)
                        .stroke(AppColors.primaryBlue, lineWidth: 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipped()
        .accessibilityLabel("Route map")
        .accessibilityValue(accessibilityRouteSummary)
        .onAppear {
            locationManager.requestPermission()
        }
        .task(id: routeTaskID) {
            await updateRoutes()
        }
    }

    private var routeTaskID: String {
        let destinations = orderedClients
            .map { "\($0.id):\($0.latitude),\($0.longitude)" }
            .joined(separator: "|")
        let origin: String
        if let currentLocation = startLocation {
            origin = "\(currentLocation.latitude),\(currentLocation.longitude)"
        } else {
            origin = "unknown-origin"
        }

        return "\(origin)|\(destinations)"
    }

    @MainActor
    private func updateRoutes() async {
        guard let currentLocation = startLocation, !orderedClients.isEmpty else { return }

        var routes: [MKRoute] = []
        var previousStop = currentLocation
        var visibleRect = MKMapRect.null

        for client in orderedClients {
            if let route = try? await route(from: previousStop, to: client.coordinate) {
                routes.append(route)
                visibleRect = visibleRect.isNull ? route.polyline.boundingMapRect : visibleRect.union(route.polyline.boundingMapRect)
                previousStop = client.coordinate
            }
        }

        routeSegments = routes

        if !visibleRect.isNull {
            position = .rect(visibleRect)
        }
    }

    private func route(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: source.latitude, longitude: source.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: destination.latitude, longitude: destination.longitude),
            address: nil
        )
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RouteError.noRouteFound
        }

        return route
    }

    private func distance(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: source.latitude, longitude: source.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
    }

    private var accessibilityRouteSummary: String {
        guard !orderedClients.isEmpty else {
            return "No destinations available."
        }

        let stops = orderedClients.enumerated()
            .map { "Stop \($0.offset + 1), \($0.element.name)" }
            .joined(separator: ". ")
        return "Nearest first route. \(stops)."
    }
}

private enum RouteError: Error {
    case noRouteFound
}

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last?.coordinate
    }
}

#Preview {
    MapSectionView(
        clients: ClientRepository.sampleClients,
        simulatedStart: CLLocationCoordinate2D(latitude: 19.4400, longitude: -99.1500)
    )
}
