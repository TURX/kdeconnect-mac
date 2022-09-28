//
//  NotificationManager.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/13.
//

import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    var categories: Set<UNNotificationCategory>
    
    init() {
        let acceptAction = UNNotificationAction(identifier: "PAIR_ACCEPT_ACTION", title: "Accept")
        let declineAction = UNNotificationAction(identifier: "PAIR_DECLINE_ACTION", title: "Decline")
        let foundAction = UNNotificationAction(identifier: "FMD_FOUND_ACTION", title: "Found")
        let normalCategory = UNNotificationCategory(identifier: "NORMAL", actions: [], intentIdentifiers: [])
        let pairRequestCategory = UNNotificationCategory(identifier: "PAIR_REQUEST", actions: [ acceptAction, declineAction ], intentIdentifiers: [], options: .customDismissAction)
        let findMyDeviceCategory = UNNotificationCategory(identifier: "FIND_MY_DEVICE", actions: [ foundAction ], intentIdentifiers: [], options: .customDismissAction)
        categories = [ normalCategory, pairRequestCategory, findMyDeviceCategory ]
    }
    
    func pairRequestPost(title: String, body: String, deviceId: String) {
        post(title: title, body: body, userInfo: [ "DEVICE_ID": deviceId ], categoryIdentifier: "PAIR_REQUEST")
    }
    
    func post(title: String, body: String, userInfo: [AnyHashable: Any] = [:], categoryIdentifier: String = "NORMAL", interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        content.categoryIdentifier = categoryIdentifier
        
        let dateComponents = DateComponents(calendar: Calendar.current)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories(self.categories)
        notificationCenter.add(request)
    }
}
