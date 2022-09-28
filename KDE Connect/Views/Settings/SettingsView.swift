//
//  PrefPane.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/12.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var selfDeviceDataForSettings: SelfDeviceData = selfDeviceData
    
    var body: some View {
        TabView {
            DeviceSettingsView(deviceName: $selfDeviceDataForSettings.deviceName)
                .tabItem {
                    Label("Device", systemImage: "display")
                }
            PeerSettingsView(directIPs: $selfDeviceDataForSettings.directIPs)
                .tabItem {
                    Label("Peer", systemImage: "laptopcomputer.and.iphone")
                }
            AppSettingsView(chosenTheme: $selfDeviceDataForSettings.chosenTheme, appIcon: $selfDeviceDataForSettings.appIcon)
                .tabItem {
                    Label("Application", systemImage: "app")
                }
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
