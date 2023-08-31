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
    @State var showingHelpWindow: Bool = false
    
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
        WindowGroup("main") {
            if !self.disabledByNotGrantedNotificationPermission {
                MainView(showingHelpWindow: self.$showingHelpWindow)
                    .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
                    .onAppear {
                        NSApplication.shared.applicationIconImage = NSImage(named: (selfDeviceDataForTopLevel.appIcon.rawValue ?? "AppIcon"))
                        requestNotification()
                        backgroundService.startDiscovery()
                        requestBatteryStatusAllDevices()
                    }
                    .environmentObject(notificationManager)
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification)) { _ in
                        requestNotification()
                    }
            } else {
                AskNotificationView()
                    .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification)) { _ in
                        requestNotification()
                    }
            }
        }
        .commands {
            CommandMenu("Devices") {
                if !self.disabledByNotGrantedNotificationPermission {
                    Button("Refresh Discovery") {
                        MainView.mainViewSingleton?.refreshDiscoveryAndList()
                    }
                } else {
                    Label("Refresh Discovery", systemImage: "")
                }
                Button("Show Received Files in Finder") {
                    let fileManager = FileManager.default
                    do {
                        // see Share plugin
                        let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                        NSWorkspace.shared.open(documentDirectory)
                    } catch {
                        print("Error showing received files in Finder \(error)")
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
    
        WindowGroup("help") {
            HelpView(showingHelpWindow: self.$showingHelpWindow)
                .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
        }
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        
        Settings {
            if !self.disabledByNotGrantedNotificationPermission {
                SettingsView()
                    .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
                    .environmentObject(selfDeviceDataForTopLevel)
            } else {
                AskNotificationView()
                    .preferredColorScheme((selfDeviceDataForTopLevel.chosenTheme == "System Default") ? nil : appThemes[selfDeviceDataForTopLevel.chosenTheme])
                    .frame(width: 450, height: 250)
            }
        }
    }
}
