//
//  ContentView.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/11.
//

import SwiftUI
import Combine

struct DevicesView: View {
    var connectedDevicesIds: [String] {
        viewModel.connectedDevices.keys.sorted()
    }
    var visibleDevicesIds: [String] {
        viewModel.visibleDevices.keys.sorted()
    }
    var savedDevicesIds: [String] {
        viewModel.savedDevices.keys.sorted()
    }
        
    @ObservedObject var viewModel: ConnectedDevicesViewModel = connectedDevicesViewModel
    
    @State public var clickedDeviceId: String
    @State private var counter: Int
    
    init() {
        self.clickedDeviceId = "-1"
        self.counter = 0
    }
    
    func getEmojiFromDeviceType(deviceType: DeviceType) -> String {
        switch (deviceType) {
        case .desktop:
            return "\u{1F5A5}"
        case .laptop:
            return "\u{1F4BB}"
        case .phone:
            return "\u{1F4F1}"
        case .tablet:
            return "\u{1F3AC}"
        case .tv:
            return "\u{1F4FA}"
        case .unknown:
            return "\u{2754}"
        @unknown default:
            return "\u{2753}"
        }
    }
    
    // no arg: actual data; int arg: preset data
    func getDeviceIcons(_ genMode: Int = -1) -> [DeviceItemView] {
        switch (genMode) {
        case 0:
            return []
        case 1:
            return [
                DeviceItemView(deviceId: "1", parent: self, deviceName: .constant("TURX's iPhone"), emoji: "\u{1F4F1}", backgroundColor: .gray),
                DeviceItemView(deviceId: "2", parent: self, deviceName: .constant("WISC InfoLab iMac"), emoji: "\u{1F5A5}", backgroundColor: .green),
                DeviceItemView(deviceId: "3", parent: self, deviceName: .constant("C"), emoji: "\u{1F5A5}", backgroundColor: .cyan),
                DeviceItemView(deviceId: "4", parent: self, deviceName: .constant("D"), emoji: "\u{1F5A5}", backgroundColor: .gray)
            ]
        case 2:
            var deviceIcons = Array<DeviceItemView>()
            for i in 1...100 {
                deviceIcons.append(DeviceItemView(deviceId: String(i), parent: self, deviceName: .constant(String(i)), emoji: "\u{1F4F1}", backgroundColor: .gray))
            }
            return deviceIcons
        default:
            var deviceIcons = Array<DeviceItemView>()
            for key in connectedDevicesIds {
                deviceIcons.append(DeviceItemView(deviceId: key, parent: self, deviceName: .constant(viewModel.connectedDevices[key] ?? "Unknown device"), emoji: getEmojiFromDeviceType(deviceType: backgroundService._devices[key]?._type ?? .unknown), backgroundColor: .green))
            }
            for key in savedDevicesIds {
                deviceIcons.append(DeviceItemView(deviceId: key, parent: self, deviceName: .constant(viewModel.savedDevices[key] ?? "Unknown device"), emoji: getEmojiFromDeviceType(deviceType: backgroundService._devices[key]?._type ?? .unknown), backgroundColor: .gray))
            }
            for key in visibleDevicesIds {
                deviceIcons.append(DeviceItemView(deviceId: key, parent: self, deviceName: .constant(viewModel.visibleDevices[key] ?? "Unknown device"), emoji: getEmojiFromDeviceType(deviceType: backgroundService._devices[key]?._type ?? .unknown), backgroundColor: .cyan))
            }
            return deviceIcons
        }
    }
    
    var body: some View {
        if getDeviceIcons().isEmpty {
            VStack {
                Spacer()
                Text("No device discovered in the current network.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView(.vertical) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128))]) {
                    ForEach(getDeviceIcons(), id: \.deviceId) {deviceIcon in
                        deviceIcon
                            .padding(.all)
                    }
                }
            }
            .padding(.all)
            .onTapGesture {
                self.clickedDeviceId = "-1"
            }
            .onAppear {
                broadcastBatteryStatusAllDevices()
            }
        }
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
    }
}
