import SwiftUI
import CoreLocation
import MapKit


struct MapSectionView: View {

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var locationManager = LocationManager()

    var body: some View {
        ZStack {
            Color.blue
            Map(position: $position) { UserAnnotation() }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipped()
        .onAppear { locationManager.requestPermission() }
    }
}




class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func requestPermission() {
        // This triggers the system popup using the text from your Info tab
        manager.requestWhenInUseAuthorization()
    }
}
#Preview {
    ContentView()
}
