import SwiftUI
import MapKit

//struct MapTestView: View {
//    
//    @State private var runViewModel = RunViewModel()
//    @State private var healthService = HealthKitService()
//    
//    var body: some View {
//        ZStack {
//            Color.rwBg.ignoresSafeArea()
//            
//            VStack(spacing: 12) {
//                Text("LOCATION DEBUG")
//                    .font(.orbitron(16, weight: .bold))
//                    .foregroundColor(.rwGreen)
//                    .kerning(2)
//                    .padding(.top, 16)
//                
//                HStack(spacing: 8) {
//                    DebugDataBox(label: "LAT", value: String(format: "%.5f", runViewModel.locationService.latitude))
//                    DebugDataBox(label: "LON", value: String(format: "%.5f", runViewModel.locationService.longitude))
//                    DebugDataBox(label: "ACC", value: String(format: "%.1f", runViewModel.locationService.accuracy), unit: "m")
//                    DebugDataBox(label: "DIST", value: String(format: "%.1f", runViewModel.distance), unit: "m")
//                }
//                .padding(.horizontal, 16)
//                
//                Map {
//                    UserAnnotation()
//                }
//                .mapControls {
//                    MapUserLocationButton()
//                }
//                .mapStyle(.standard(pointsOfInterest: .excludingAll))
//                .frame(height: 400)
//                .clipShape(RoundedRectangle(cornerRadius: 16))
//                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rwBorder, lineWidth: 1))
//                .padding(.horizontal, 16)
//                
//                HStack(spacing: 12) {
//                    Button {
//                        runViewModel.start()
//                    } label: {
//                        Text("START")
//                            .font(.orbitron(13, weight: .bold))
//                            .foregroundColor(.rwBg)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(Color.rwGreen)
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//                    
//                    Button {
//                        runViewModel.stop()
//                    } label: {
//                        Text("STOP")
//                            .font(.orbitron(13, weight: .bold))
//                            .foregroundColor(.rwBg)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(Color.rwRed)
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//                }
//                .padding(.horizontal, 16)
//                
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 4) {
//                        ForEach(runViewModel.locationService.logs, id: \.self) { log in
//                            Text(log)
//                                .font(.system(size: 11, design: .monospaced))
//                                .foregroundColor(.rwGreen)
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                        }
//                    }
//                    .padding(12)
//                }
//                .frame(height: 160)
//                .background(Color.rwPanel)
//                .clipShape(RoundedRectangle(cornerRadius: 12))
//                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
//                .padding(.horizontal, 16)
//            }
//        }
//        .task {
//            await runViewModel.startStream()
//        }
//
//    }
//}
//
//struct DebugDataBox: View {
//    let label: String
//    let value: String
//    var unit: String = ""
//    
//    var body: some View {
//        VStack(spacing: 4) {
//            Text(label)
//                .font(.system(size: 9, weight: .medium))
//                .foregroundColor(.rwMuted)
//                .kerning(1.5)
//            HStack(alignment: .lastTextBaseline, spacing: 2) {
//                Text(value)
//                    .font(.orbitron(11, weight: .bold))
//                    .foregroundColor(.rwGreen)
//                if !unit.isEmpty {
//                    Text(unit)
//                        .font(.system(size: 9))
//                        .foregroundColor(.rwMuted)
//                }
//            }
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 12)
//        .background(Color.rwPanel)
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rwBorder, lineWidth: 1))
//    }
//}
//
//#Preview {
//    MapTestView()
//}
