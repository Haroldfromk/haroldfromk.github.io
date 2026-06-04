//
//  FlightSummaryView.swift
//  RunWay
//

import SwiftUI
import MapKit

// MARK: - Sample Route
struct SampleRoute {
    // 부산 해운대 근처 샘플 좌표
    static let coordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 35.1587, longitude: 129.1600),
        CLLocationCoordinate2D(latitude: 35.1595, longitude: 129.1615),
        CLLocationCoordinate2D(latitude: 35.1608, longitude: 129.1628),
        CLLocationCoordinate2D(latitude: 35.1622, longitude: 129.1635),
        CLLocationCoordinate2D(latitude: 35.1638, longitude: 129.1628),
        CLLocationCoordinate2D(latitude: 35.1650, longitude: 129.1612),
        CLLocationCoordinate2D(latitude: 35.1658, longitude: 129.1595),
        CLLocationCoordinate2D(latitude: 35.1652, longitude: 129.1578),
        CLLocationCoordinate2D(latitude: 35.1640, longitude: 129.1565),
        CLLocationCoordinate2D(latitude: 35.1625, longitude: 129.1558),
        CLLocationCoordinate2D(latitude: 35.1610, longitude: 129.1562),
        CLLocationCoordinate2D(latitude: 35.1598, longitude: 129.1575),
        CLLocationCoordinate2D(latitude: 35.1590, longitude: 129.1588),
        CLLocationCoordinate2D(latitude: 35.1587, longitude: 129.1600),
    ]

    static var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.1622, longitude: 129.1597),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }
}

// MARK: - Route Map View
struct RouteMapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false
        mapView.delegate = context.coordinator

        // Region
        mapView.setRegion(SampleRoute.region, animated: false)

        // Polyline
        let polyline = MKPolyline(
            coordinates: SampleRoute.coordinates,
            count: SampleRoute.coordinates.count
        )
        mapView.addOverlay(polyline)

        // Start annotation
        let start = MKPointAnnotation()
        start.coordinate = SampleRoute.coordinates.first!
        start.title = "START"
        mapView.addAnnotation(start)

        // End annotation
        let end = MKPointAnnotation()
        end.coordinate = SampleRoute.coordinates.last!
        end.title = "END"
        mapView.addAnnotation(end)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.rwGreen)
                renderer.lineWidth = 3.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.markerTintColor = UIColor(Color.rwGreen)
            view.glyphTintColor = UIColor(Color.rwBg)
            view.glyphText = annotation.title == "START" ? "S" : "E"
            return view
        }
    }
}

// MARK: - Flight Summary View
struct FlightSummaryView: View {
    @State private var navigateToLogbook = false

    var body: some View {
        ZStack {
            Color.rwBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {

                    // MISSION COMPLETE badge
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.rwGreen)
                        Text("MISSION COMPLETE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.rwGreen)
                            .kerning(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.rwGreen.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.rwGreen.opacity(0.3), lineWidth: 1))
                    .padding(.top, 12)

                    // Mission info + Map
                    VStack(spacing: 0) {
                        // Top info row
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.rwGreen.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "airplane")
                                    .foregroundColor(.rwGreen)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MISSION FLIGHT")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.rwGreen)
                                Text("Airbus A320-200")
                                    .font(.system(size: 9))
                                    .foregroundColor(.rwMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text("8.42")
                                        .font(.orbitron(18, weight: .bold))
                                        .foregroundColor(.rwText)
                                    Text("km")
                                        .font(.system(size: 10))
                                        .foregroundColor(.rwMuted)
                                }
                                HStack(alignment: .lastTextBaseline, spacing: 2) {
                                    Text("5'42\"")
                                        .font(.orbitron(13, weight: .bold))
                                        .foregroundColor(.rwAmber)
                                    Text("/km")
                                        .font(.system(size: 9))
                                        .foregroundColor(.rwMuted)
                                }
                            }
                        }
                        .padding(14)

                        // Map
                        RouteMapView()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                    }
                    .background(Color.rwPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwBorder, lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        SummaryStatBox(label: "TIME", value: "48:12", unit: "", color: .rwText)
                        SummaryStatBox(label: "AVG PACE", value: "5'42\"", unit: "/km", color: .rwAmber)
                        SummaryStatBox(label: "AVG HR", value: "153", unit: "bpm", color: .rwRed)
                    }
                    .padding(.horizontal, 16)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        SummaryStatBox(label: "CADENCE", value: "172", unit: "spm", color: .rwGreen)
                        SummaryStatBox(label: "FLIGHT LOAD", value: "86%", unit: "", color: .rwGreen)
                    }
                    .padding(.horizontal, 16)

                    // Save button
                    Button {
                        navigateToLogbook = true
                    } label: {
                        Text("SAVE TO LOGBOOK")
                            .font(.orbitron(13, weight: .bold))
                            .foregroundColor(.rwBg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.rwGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
            }
        }
        .navigationTitle("FLIGHT SUMMARY")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.rwPanel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToLogbook) {
            LogbookView()
        }
    }
}

// MARK: - Stat Box
struct SummaryStatBox: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.rwMuted)
                .kerning(1.5)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.orbitron(18, weight: .bold))
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(.rwMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.rwPanel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { FlightSummaryView() }
}
