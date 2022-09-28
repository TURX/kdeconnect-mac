//
//  DeviceIcon.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/11.
//

import SwiftUI
import MediaPicker

struct DeviceItemView: View {
    var deviceId: String
    var parent: DevicesView?
    @Binding var deviceName: String
    var emoji: String
    var backgroundColor: Color
    
    init(deviceId: String, parent: DevicesView? = nil, deviceName: Binding<String>, emoji: String, backgroundColor: Color) {
        self.deviceId = deviceId
        self.parent = parent
        self._deviceName = deviceName
        self.emoji = emoji
        self.backgroundColor = backgroundColor
    }
    
    @State private var showingPhotosPicker: Bool = false
    @State private var showingFilePicker: Bool = false
    @State var chosenFileURLs: [URL] = []
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(parent?.clickedDeviceId == self.deviceId ? Color.accentColor : self.backgroundColor)
                    .zIndex(0)
                HStack {
                    Text(emoji)
                        .font(.system(size: 32))
                        .zIndex(1)
                }
            }
            .frame(width: 64, height: 64)
            HStack {
                Text(deviceName)
                    .multilineTextAlignment(.center)
                    .foregroundColor(parent?.clickedDeviceId == self.deviceId ? .white : .primary)
                    .padding(.horizontal, 8)
            }.background(RoundedRectangle(cornerRadius: 8)
                    .fill(parent?.clickedDeviceId == self.deviceId ? .accentColor : Color.blue.opacity(0)))
        }.onTapGesture {
            parent?.clickedDeviceId = self.deviceId
        }.contextMenu {
            if parent?.clickedDeviceId == self.deviceId {
                if backgroundService.devices[self.deviceId]?.isPaired() ?? false {
                    Button("Unpair") {
                        backgroundService.unpairDevice(self.deviceId)
                    }
                    if let pluginsEnableStatus = backgroundService.devices[self.deviceId]?.pluginsEnableStatus, let pluginsList = backgroundService.devices[self.deviceId]?.plugins {
                        if (pluginsEnableStatus[.ping] != nil) {
                            Button("Ping") {
                                (pluginsList[.ping] as! Ping).sendPing()
                            }
                        }
                        if (pluginsEnableStatus[.clipboard] != nil) {
                            Button("Push Local Clipboard") {
                                (pluginsList[.clipboard] as! Clipboard).sendClipboardContentOut()
                            }
                        }
                        if (pluginsEnableStatus[.share] != nil) {
                            Button("Send Photos and Videos") {
                                showingPhotosPicker = true
                            }
                            Button("Send Files") {
                                showingFilePicker = true
                            }
                        }
                    }
                } else {
                    Button("Pair") {
                        backgroundService.pairDevice(self.deviceId)
                    }
                }
            }
        }.mediaImporter(isPresented: $showingPhotosPicker, allowedMediaTypes: .all, allowsMultipleSelection: true) { result in
            if case .success(let chosenMediaURLs) = result, !chosenMediaURLs.isEmpty {
                (backgroundService._devices[self.deviceId]!._plugins[.share] as! Share).prepAndInitFileSend(fileURLs: chosenMediaURLs)
            } else {
                print("Media Picker Result: \(result)")
            }
        }.fileImporter(isPresented: $showingFilePicker, allowedContentTypes: allUTTypes, allowsMultipleSelection: true) { result in
            do {
                chosenFileURLs = try result.get()
            } catch {
                print("Document Picker Error")
            }
            if (chosenFileURLs.count > 0) {
                (backgroundService._devices[self.deviceId]!._plugins[.share] as! Share).prepAndInitFileSend(fileURLs: chosenFileURLs)
            }
        }
    }
}

struct DeviceIcon_Previews: PreviewProvider {
    static var previews: some View {
        DeviceItemView(deviceId: "0", parent: nil, deviceName: .constant("TURX's MacBook Pro"), emoji: "\u{1F5A5}", backgroundColor: .gray)
    }
}
