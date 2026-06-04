//
//  HomeView.swift
//  RunWay
//

import SwiftUI
import CoreLocation

// MARK: - 샘플 경로 좌표 → Path 변환
func makeRoutePath(coordinates: [CLLocationCoordinate2D], in rect: CGRect) -> Path {
    guard coordinates.count > 1 else { return Path() }
    
    let lats = coordinates.map(\.latitude)
    let lngs = coordinates.map(\.longitude)
    let minLat = lats.min()!, maxLat = lats.max()!
    let minLng = lngs.min()!, maxLng = lngs.max()!
    
    let latRange = maxLat - minLat
    let lngRange = maxLng - minLng
    let range = max(latRange, lngRange, 0.0001)
    
    return Path { path in
        coordinates.enumerated().forEach { i, coord in
            let x = CGFloat((coord.longitude - minLng) / range) * rect.width * 0.85 + rect.width * 0.07
            let y = CGFloat(1 - (coord.latitude - minLat) / range) * rect.height * 0.85 + rect.height * 0.07
            let point = CGPoint(x: x, y: y)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
    }
}

// MARK: - Sample coordinates (부산 해운대 루프)
let sampleRouteCoordinates: [CLLocationCoordinate2D] = [
    CLLocationCoordinate2D(latitude: 35.1587, longitude: 129.1600),
    CLLocationCoordinate2D(latitude: 35.1595, longitude: 129.1615),
    CLLocationCoordinate2D(latitude: 35.1610, longitude: 129.1628),
    CLLocationCoordinate2D(latitude: 35.1628, longitude: 129.1635),
    CLLocationCoordinate2D(latitude: 35.1642, longitude: 129.1622),
    CLLocationCoordinate2D(latitude: 35.1650, longitude: 129.1605),
    CLLocationCoordinate2D(latitude: 35.1645, longitude: 129.1585),
    CLLocationCoordinate2D(latitude: 35.1630, longitude: 129.1572),
    CLLocationCoordinate2D(latitude: 35.1612, longitude: 129.1568),
    CLLocationCoordinate2D(latitude: 35.1597, longitude: 129.1578),
    CLLocationCoordinate2D(latitude: 35.1587, longitude: 129.1600),
]

// MARK: - HomeView
struct HomeView: View {
    let weeklyKm: [Double] = [3.2, 5.1, 0, 6.8, 4.2, 8.42, 0]
    let weekDays = ["M", "T", "W", "T", "F", "S", "S"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.rwBg.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("RUNWAY")
                                    .font(.orbitron(24, weight: .black))
                                    .foregroundColor(.rwGreen)
                                Image(systemName: "airplane")
                                    .foregroundColor(.rwGreen)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            Text("Good evening, Pilot.")
                                .font(.system(size: 13))
                                .foregroundColor(.rwMuted)
                            Text("Ready for your next flight?")
                                .font(.system(size: 13))
                                .foregroundColor(.rwMuted)
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.rwMuted)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Mission Flight Card
                    NavigationLink(destination: ModeAView()) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "airplane")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.rwGreen)
                                    Text("MISSION FLIGHT")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.rwGreen)
                                        .kerning(1)
                                    Text("Airbus A320-200")
                                        .font(.system(size: 10))
                                        .foregroundColor(.rwMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.rwMuted)
                                    .font(.system(size: 13))
                            }
                            
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TARGET PACE")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.rwMuted)
                                        .kerning(1.5)
                                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                                        Text("5'30\"")
                                            .font(.orbitron(36, weight: .bold))
                                            .foregroundColor(.rwGreen)
                                        Text("/km")
                                            .font(.system(size: 13))
                                            .foregroundColor(.rwMuted)
                                    }
                                }
                                Spacer()
                                Image(systemName: "airplane")
                                    .font(.system(size: 52))
                                    .foregroundColor(.rwGreen.opacity(0.12))
                                    .rotationEffect(.degrees(-10))
                            }
                        }
                        .padding(16)
                        .background(Color.rwPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwGreen.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    
                    // Free Flight Card
                    NavigationLink(destination: TakeoffView()) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "airplane.departure")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.rwAmber)
                                Text("FREE FLIGHT")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.rwAmber)
                                    .kerning(1)
                                Text("VFR")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.rwAmber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.rwAmber.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            Text("목표 없이 자유 러닝")
                                .font(.system(size: 11))
                                .foregroundColor(.rwMuted)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.rwMuted)
                                .font(.system(size: 13))
                                .padding(.leading, 4)
                        }
                        .padding(16)
                        .background(Color.rwPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwAmber.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    
                    // Last Flight
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LAST FLIGHT")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.rwMuted)
                            .kerning(1.5)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Busan Night Run")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.rwText)
                                Text("2024.05.24")
                                    .font(.system(size: 10))
                                    .foregroundColor(.rwMuted)
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("8.42 km")
                                            .font(.orbitron(18, weight: .bold))
                                            .foregroundColor(.rwText)
                                        Text("DISTANCE")
                                            .font(.system(size: 8))
                                            .foregroundColor(.rwMuted)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("5'42\"")
                                            .font(.orbitron(18, weight: .bold))
                                            .foregroundColor(.rwAmber)
                                        Text("AVG PACE")
                                            .font(.system(size: 8))
                                            .foregroundColor(.rwMuted)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("153")
                                            .font(.orbitron(18, weight: .bold))
                                            .foregroundColor(.rwRed)
                                        Text("HR AVG")
                                            .font(.system(size: 8))
                                            .foregroundColor(.rwMuted)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            
                            Spacer()
                            
                            // Route Path 미리보기
                            GeometryReader { geo in
                                let path = makeRoutePath(coordinates: sampleRouteCoordinates, in: geo.frame(in: .local))
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.rwPanel2)
                                    
                                    // 시작점
                                    Circle()
                                        .fill(Color.rwGreen)
                                        .frame(width: 6, height: 6)
                                        .position(
                                            makeRoutePath(coordinates: sampleRouteCoordinates, in: geo.frame(in: .local))
                                                .currentPoint ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                        )
                                    
                                    path
                                        .stroke(Color.rwGreen, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                }
                            }
                            .frame(width: 100, height: 90)
                        }
                    }
                    .padding(16)
                    .background(Color.rwPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    
                    // Weekly Chart
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("WEEKLY FLIGHT HOURS")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.rwMuted)
                                .kerning(1.5)
                            Spacer()
                            Text("5'42\" avg")
                                .font(.orbitron(11, weight: .bold))
                                .foregroundColor(.rwGreen)
                        }
                        
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(Array(weeklyKm.enumerated()), id: \.offset) { i, km in
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            km > 0
                                            ? LinearGradient(colors: [.rwGreen2, .rwGreen], startPoint: .bottom, endPoint: .top)
                                            : LinearGradient(colors: [Color.rwPanel2, Color.rwPanel2], startPoint: .bottom, endPoint: .top)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .frame(height: max(6, km / 10 * 60))
                                    Text(weekDays[i])
                                        .font(.system(size: 10))
                                        .foregroundColor(i == 5 ? .rwGreen : .rwMuted)
                                }
                            }
                        }
                        .frame(height: 68)
                        
                        Text("21.4 km total this week")
                            .font(.orbitron(13, weight: .bold))
                            .foregroundColor(.rwText)
                    }
                    .padding(16)
                    .background(Color.rwPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
}


#Preview {
    HomeView()
}
