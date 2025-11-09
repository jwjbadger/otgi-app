//
//  otgiApp.swift
//  otgi
//
//  Created by jwjbadger on 10/9/25.
//

import SwiftUI
import SwiftData

@main
struct otgiApp: App {
    @StateObject private var bluetoothManager = BluetoothManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
                
        }
        .onChange(of: scenePhase) {
                    if scenePhase == .background {
                        bluetoothManager.save()
                    }
                }
    }
}
