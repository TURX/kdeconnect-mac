//
//  DeviceIcon.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/11.
//

import SwiftUI
import MediaPicker

struct DeviceItemView: View {
    let deviceId: String
    let parent: DevicesView?
    @Binding var deviceName: String
    let emoji: String
    let connState: DevicesView.ConnectionState
    let backgroundColor: Color
    @Environment(\.colorScheme) var colorScheme
    
    init(deviceId: String, parent: DevicesView? = nil, deviceName: Binding<String>, emoji: String, connState: DevicesView.ConnectionState) {
        self.deviceId = deviceId
        self.parent = parent
        self._deviceName = deviceName
        self.emoji = emoji
        switch (connState) {
        case .connected:
            self.backgroundColor = .green
        case .saved:
            self.backgroundColor = .gray
        case .visible:
            self.backgroundColor = .cyan
        case .local:
            self.backgroundColor = .cyan
        }
        self.connState = connState
    }

    func isPluginAvailable(_ plugin: NetworkPackage.`Type`) -> Bool {
        if let pluginsEnableStatus = backgroundService.devices[deviceId]?.pluginsEnableStatus {
            if pluginsEnableStatus[plugin] != nil {
                return (backgroundService.devices[deviceId]?.isPaired() ?? false) && (backgroundService.devices[deviceId]?.isReachable() ?? false)
            }
            return false
        }
        return false
    }
    
    @State private var showingPhotosPicker: Bool = false
    @State private var showingFilePicker: Bool = false
    @State var chosenFileURLs: [URL] = []
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(parent?.clickedDeviceId == self.deviceId ? Color.accentColor : self.backgroundColor)
                if self.connState == .connected && self.isPluginAvailable(.batteryRequest) {
                    BatteryStatus(device: backgroundService._devices[self.deviceId]!) { battery in
                        Circle()
                            .trim(from: 0, to: CGFloat(battery.remoteChargeLevel) / 100)
                            .rotation(.degrees(-90))
                            .stroke(battery.statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .brightness(colorScheme == .light ? -0.1 : 0.1)
                        Text(String(battery.remoteChargeLevel) + "%")
                            .frame(maxWidth: 64, maxHeight: 64, alignment: .top)
                            .padding(.top, 2)
                            .font(.system(.footnote, design: .rounded).weight(.light))
                            .foregroundColor(.black)
                    }.onAppear {
                        (backgroundService._devices[self.deviceId]!._plugins[.batteryRequest] as! Battery)
                            .sendBatteryStatusOut()
                    }
                }
                Text(emoji)
                    .font(.system(size: 32))
                    .shadow(radius: 1)
            }
            .frame(width: 64, height: 64)
            HStack {
                Text(deviceName)
                    .multilineTextAlignment(.center)
                    .foregroundColor(parent?.clickedDeviceId == self.deviceId ? .white : Color.primary)
                    .padding(.horizontal, 8)
            }.background(RoundedRectangle(cornerRadius: 8)
                .fill(parent?.clickedDeviceId == self.deviceId ? .accentColor : Color.blue.opacity(0)))
        }.onTapGesture {
            parent?.clickedDeviceId = self.deviceId
        }.onDrop(of: [.fileURL], isTargeted: nil) { providers in
            // Ref: https://stackoverflow.com/questions/60831260/swiftui-drag-and-drop-files
            if isPluginAvailable(.share) {
                var droppedFileURLs: [URL] = []
                providers.forEach { provider in
                    provider.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
                        if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                            droppedFileURLs.append(url)
                            print("File drppped: ", url)
                        }
                    })
                }
                while droppedFileURLs.count != providers.count {
                    continue // block thread until all providers are proceeded
                }
                (backgroundService._devices[self.deviceId]!._plugins[.share] as! Share).prepAndInitFileSend(fileURLs: droppedFileURLs)
                return true
            } else {
                return false
            }
        }.contextMenu {
            if parent?.clickedDeviceId == self.deviceId {
                if backgroundService.devices[self.deviceId]?.isPaired() ?? false {
                    Button("Unpair") {
                        backgroundService.unpairDevice(self.deviceId)
                    }
                    if backgroundService.devices[self.deviceId]?.isReachable() ?? false {
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
                                // TODO: fix media sharing
//                                Button("Send Photos and Videos") {
//                                    showingPhotosPicker = true
//                                }
                                Button("Send Files") {
                                    showingFilePicker = true
                                }
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
        DeviceItemView(deviceId: "0", parent: nil, deviceName: .constant("TURX's MacBook Pro"), emoji: "\u{1F5A5}", connState: .local)
    }
}
