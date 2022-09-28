//
//  AppDelegate.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/13.
//

import Foundation
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var menu: NSMenu? = nil
    private var safe: Bool = true
    private var needMenuUpdate: Bool = false {
        didSet {
            if self.needMenuUpdate == true {
                if safe {
                    safe = false
                    self.menu?.items.removeAll(where: { $0.title != "KDE Connect" && $0.title != "Devices" })
                    safe = true
                }
                self.needMenuUpdate = false
            }
        }
    }
    
    func requestMenuUpdate() {
        if menu?.items.count != 2 {
            self.needMenuUpdate = true
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        let deviceId = userInfo["DEVICE_ID"] as? String ?? nil
        
        switch response.actionIdentifier {
        case "PAIR_ACCEPT_ACTION":
            backgroundService.pairDevice(deviceId)
            break
        case "PAIR_DECLINE_ACTION":
            backgroundService.unpairDevice(deviceId)
            break
        case "FMD_FOUND_ACTION":
            MainView.updateFindMyPhoneTimer(isRunning: false)
            break
        default:
            break
        }
        
        completionHandler()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let menu = NSApplication.shared.mainMenu {
            self.menu = menu
            self.requestMenuUpdate()
        }
    }
    
    func applicationWillUpdate(_ notification: Notification) {
        if let menu = NSApplication.shared.mainMenu {
            self.menu = menu
            self.requestMenuUpdate()
        }
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }
}
