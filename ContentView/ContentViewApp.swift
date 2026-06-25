//
//  ContentViewApp.swift
//  ContentView
//
//  Created by honman luk on 19/10/2024.
//

import SwiftUI
import Firebase

@main
struct ContentViewApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    @StateObject private var tabBarManager = TabBarManager()
    @StateObject private var userSettings = UserSettings.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                MainTabView()
                    .environmentObject(tabBarManager)
                    .environmentObject(userSettings)
            }
        }
    }
}
