//
//  ContentView.swift
//  otgi
//
//  Created by jwjbadger on 10/9/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Query private var items: [Item]

    var body: some View {
        VStack {
            Text(
                bluetoothManager.bluetoothEnabled
                ? "Bluetooth is ON" : "Bluetooth is OFF"
            )
            .padding()
            Text(
                bluetoothManager.connected
                ? "Bluetooth is CONNECTED" : "Bluetooth is DISCONNECTED"
            )
            .padding()
            Text(
                "Trip Fuel Usage (Liters): \(bluetoothManager.estimatedTripFuelUsage?.description ?? "No Value")"
            )
            .padding()
            Text(
                "Received Runcount: \(bluetoothManager.runcount?.description ?? "NO")"
            )
            .padding()
            let tripFuel = bluetoothManager.estimatedTripFuelUsage ?? 0.0
            let remainingFuelGallons = (80.0 - bluetoothManager.storedTankUsage - tripFuel) * 0.264172
            Text(
                "Estimated Remaining Fuel (Gallons): \(remainingFuelGallons)"
            )
            .padding()
            Text(
                "Estimated Miles Remaining: \(remainingFuelGallons * 17.0)" // Estimated 17 mpg; eventually update this
            )
            .padding()
            Text("Any Errors: \(bluetoothManager.error.debugDescription)")
                .padding()
            Button("Fuel Up") {
                bluetoothManager.storedTankUsage = -1.0 * tripFuel
            }.padding()
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
