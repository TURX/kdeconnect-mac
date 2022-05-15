//
//  KDE_ConnectApp.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/11.
//

import SwiftUI
import UserNotifications

@main
struct KDE_Connect_App: App {
    @ObservedObject var selfDeviceDataForTopLevel: SelfDeviceData = selfDeviceData
    @StateObject var notificationManager: NotificationManager = NotificationManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var disabledByNotGrantedNotificationPermission: Bool = false
    let mainView: MainView
    
    init() {
        self.mainView = MainView()
    }
    
    func requestNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if error != nil {
                self.disabledByNotGrantedNotificationPermission = true
            } else {
                self.disabledByNotGrantedNotificationPermission = false
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !self.disabledByNotGrantedNotificationPermission {
                mainView
                    .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
                    .onAppear {
                        NSApplication.shared.applicationIconImage = NSImage(named: (selfDeviceDataForTopLevel.appIcon.rawValue ?? "AppIcon"))
                        requestNotification()
                        backgroundService.startDiscovery()
                        requestBatteryStatusAllDevices()
                        broadcastBatteryStatusAllDevices()
                    }
                    .environmentObject(notificationManager)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification)) { _ in
                        requestNotification()
                        broadcastBatteryStatusAllDevices()
                    }
            } else {
                AskNotificationView()
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification)) { _ in
                        requestNotification()
                    }
            }
        }
        .commands {
            CommandMenu("Devices") {
                if !self.disabledByNotGrantedNotificationPermission {
                    Button("Refresh Discovery") {
                        mainView.refreshDiscoveryAndList()
                    }
                } else {
                    Label("Refresh Discovery", systemImage: "")
                }
            }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        
        Settings {
            if !self.disabledByNotGrantedNotificationPermission {
                SettingsView()
                    .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
                    .environmentObject(selfDeviceDataForTopLevel)
            } else {
                AskNotificationView()
                    .frame(width: 450, height: 250)
            }
        }
    }
}
