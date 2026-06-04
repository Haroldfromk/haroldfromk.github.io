//
//  ContentView.swift
//  RunWay
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem {
                    Label("Deck", systemImage: "house.fill")
                }
                .tag(0)

            NavigationStack { LogbookView() }
                .tabItem {
                    Label("Logbook", systemImage: "list.bullet.clipboard")
                }
                .tag(1)

            NavigationStack { AircraftView() }
                .tabItem {
                    Label("Aircraft", systemImage: "airplane")
                }
                .tag(2)

            NavigationStack { AlertsView() }
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }
                .tag(3)

            NavigationStack { SettingsView() }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(4)
        }
        .tint(.rwGreen)
        .preferredColorScheme(.dark)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.rwPanel)
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.rwMuted)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(Color.rwMuted)
            ]
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.rwGreen)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.rwGreen)
            ]
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
}
