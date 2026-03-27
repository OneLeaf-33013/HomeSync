//
//  ContentView.swift
//  HomeSync
//
//  Created by Samarth Bhate on 18/03/26.
//

import SwiftUI
import CoreBluetooth


struct ContentView: View {
    @State private var buttonsActivated = [false, false, false, false, false, false]
    
    @EnvironmentObject var bleManager: BLEManager
    
    private var connectedColors: [Color] {
        [Color(red: 0, green: 3/255, blue: 1), Color(red: 69/255, green: 233/255, blue: 1)]
    }
    private var disconnectedColors: [Color] {
        [Color(red: 1, green: 0, blue: 0), Color(red: 134/255, green: 0, blue: 0)]
    }
    
    private let deviceCards: [(symbol: String, systemName: String, name: String, sends: String)] = [
        ("LIGHT", "lightbulb", "Living Room Light", "0"),
        ("LIGHT", "lightbulb", "Bedroom Light", "2"),
        ("FAN", "fan.ceiling", "Fan", "1")
    ]
    
    @State private var showSettings = false
    @State private var detected = false
    
    @State private var displayFieldLine1 = ""
    @State private var displayFieldLine2 = ""
    
    // GRID: 2 columns, wide cards
    private let columns = [
        GridItem(.flexible(), spacing: 24),
        GridItem(.flexible(), spacing: 24)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: bleManager.connectedPeripheral != nil ? connectedColors : disconnectedColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white, lineWidth: 2)
                    .padding()
                
                VStack {
                    
                    // SETTINGS BUTTON
                    HStack {
                        Spacer()
                        Button {
                            showSettings.toggle()
                        } label: {
                            Image(systemName: "gear")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        .padding()
                    }
                    
                    if bleManager.connectedPeripheral == nil {
                        Spacer()
                        Text("Connect to Bluetooth!")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                        Spacer()
                    } else {
                        
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 24) {
                                
                                // BASIC DEVICES
                                ForEach(Array(deviceCards.enumerated()), id: \.offset) { index, device in
                                    Card(
                                        symbol: device.symbol,
                                        systemName: device.systemName,
                                        name: device.name,
                                        sends: device.sends,
                                        isActivated: $buttonsActivated[index]
                                    )
                                    .frame(height: 140)
                                    .padding()
                                     // WIDE > TALL
                                }
                                
                                // DISPLAY CARD
                                Card(
                                    symbol: "DISPLAY",
                                    systemName: "display",
                                    name: "Display",
                                    sends: "3",
                                    isActivated: $buttonsActivated[3],
                                    onContextButtonTap: {
                                        if !buttonsActivated[3] {
                                            buttonsActivated[3] = true
                                        }
                                    }
                                ) {
                                    DisplayFieldView(
                                        line1: $displayFieldLine1,
                                        line2: $displayFieldLine2
                                    ) {
                                        func asciiEncoded(_ string: String) -> String {
                                            string.unicodeScalars
                                                .map { String($0.value) }
                                                .joined(separator: "_")
                                        }
                                        
                                        let dataString =
                                        "0;\(asciiEncoded(displayFieldLine1));1;\(asciiEncoded(displayFieldLine2))\r\n"
                                        
                                        // split: ArraySlice<String.SubSequence> = asciiEncoded(displayFieldLine1).split(seperator: "_")
                                        
                                        
                                        
                                        
                                        
                                        
                                        bleManager.send(data: dataString)
                                    }
                                }
                                
                                .frame(height: 140)
                                .padding()
                                
                                // TEMP SENSOR
                                Card(
                                    symbol: "SENSOR",
                                    systemName: "thermometer",
                                    name: "Temperature",
                                    sends: "4",
                                    isActivated: $buttonsActivated[4]
                                ) {
                                    SensorDetailView(isDoorSensor: false)
                                        .environmentObject(bleManager)
                                }
                                
                                .frame(height: 140)
                                .padding()
                                
                                // DOOR SENSOR
                                Card(
                                    symbol: "SENSOR",
                                    systemName: "door.right.hand.open",
                                    name: "Door",
                                    sends: "5",
                                    isActivated: $buttonsActivated[5]
                                ) {
                                    SensorDetailView(isDoorSensor: true)
                                        .environmentObject(bleManager)
                                }
                            
                                .frame(height: 140)
                                .padding()
                            }
                            .padding(32)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .sheet(isPresented: $showSettings) {
                SettingsView(showSettings: $showSettings)
            }
            .onAppear {
                showSettings.toggle()
            }
            .onChange(of: bleManager.doorMotionDetected ?? false) { _, newValue in
                if newValue && !buttonsActivated[5] {
                    detected = true
                }
            }
            .alert("Someone at yo door", isPresented: $detected) {
                Button("Alr") {
                    detected = false
                }
            }
        }
    }
}
