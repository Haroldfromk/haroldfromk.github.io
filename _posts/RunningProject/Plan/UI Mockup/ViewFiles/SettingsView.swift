//
//  SettingsView.swift
//  RunWay
//

import SwiftUI

struct SettingsView: View {
    @State private var audioAlerts = true
    @State private var hapticFeedback = true
    @State private var voiceCallouts = "Rotate, Minimums..."
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.rwBg.ignoresSafeArea()
            
            
            VStack(spacing: 10) {
                // Header
                Text("SETTINGS")
                    .font(.orbitron(20, weight: .bold))
                    .foregroundColor(.rwText)
                    .kerning(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Settings rows
                VStack(spacing: 0) {
                    SettingsRow(label: "UNITS") {
                        Text("Metric (km, km/h)")
                            .font(.system(size: 12))
                            .foregroundColor(.rwMuted)
                    }
                    
                    SettingsToggleRow(label: "AUDIO ALERTS", isOn: $audioAlerts, color: .rwGreen)
                    
                    SettingsToggleRow(label: "HAPTIC FEEDBACK", isOn: $hapticFeedback, color: .rwGreen)
                    
                    SettingsRow(label: "VOICE CALLOUTS") {
                        Text("Rotate, Minimums...")
                            .font(.system(size: 12))
                            .foregroundColor(.rwMuted)
                    }
                    
                    SettingsRow(label: "APPLE WATCH") {
                        HStack(spacing: 4) {
                            Circle().fill(Color.rwGreen).frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.system(size: 12))
                                .foregroundColor(.rwGreen)
                        }
                    }
                    
                    SettingsRow(label: "HEALTH") {
                        HStack(spacing: 4) {
                            Circle().fill(Color.rwGreen).frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.system(size: 12))
                                .foregroundColor(.rwGreen)
                        }
                    }
                    
                    SettingsRow(label: "THEME") {
                        Text("Aviation Dark")
                            .font(.system(size: 12))
                            .foregroundColor(.rwMuted)
                    }
                    
                    SettingsRow(label: "ABOUT RUNWAY") {
                        Text("v1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.rwMuted)
                    }
                    
                    
                }
                .background(Color.rwPanel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rwBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                
                Spacer()
            }
            
            
            
        }
        .navigationBarHidden(true)
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content
    
    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rwText)
            Spacer()
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.rwBorder), alignment: .bottom)
    }
}

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rwText)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(color)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(.rwBorder), alignment: .bottom)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
