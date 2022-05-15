/*
 * SPDX-FileCopyrightText: 2021 Lucas Wang <lucas.wang@tuta.io>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

// Original header below:
//
//  Battery.swift
//  KDE Connect Test
//
//  Created by Lucas Wang on 2021-08-13.
//


import SwiftUI
#if !os(macOS)
import UIKit
#else
import AppKit
#endif

// TODO: We might be able to do something with the background activities plugin where it sends out its battery status every once in a while??? But maybe iOS will not unfreeze the entire app for us??? I really don't know...background activity is something that we'll have to figure out later on
@objc class Battery: NSObject, ObservablePlugin {
    @objc weak var controlDevice: Device!
    @Published
    @objc var remoteChargeLevel: Int = 0
    @Published
    @objc var remoteIsCharging: Bool = false
    @Published
    @objc var remoteThresholdEvent: Int = 0
#if os(macOS)
    var batteryLevel: Int = 0
    var acPowered: Bool = false
//    static var shared: Battery? = nil
//    var internalBatteryLevelVal: Int = 0
//    var internalBatteryLevel: Binding<Int> {
//        Binding<Int>(
//            get: {
//                self.internalBatteryLevelVal
//            },
//            set: { val in
//                if (val != self.internalBatteryLevelVal) {
//                    self.internalBatteryLevelVal = val
//                    self.batteryUpdate()
//                }
//            }
//        )
//    }
#endif
    
    @objc init(controlDevice: Device) {
        self.controlDevice = controlDevice
        super.init()
        //self.sendBatteryStatusRequest() // no need here, asking in Device() when first link is added
        self.startBatteryMonitoring()
        self.sendBatteryStatusOut()
        //Battery.shared = self
    }
    
    @objc func startBatteryMonitoring() {
#if !os(macOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Tip: to add an observer with a function/selector in another class that is not self,
        // simply replace both self in the call with the instance where the function is located
        NotificationCenter.default.addObserver(self, selector: #selector(self.batteryStateDidChange(notification:)), name: UIDevice.batteryStateDidChangeNotification, object: UIDevice.current)
        NotificationCenter.default.addObserver(self, selector: #selector(self.batteryLevelDidChange(notification:)), name: UIDevice.batteryLevelDidChangeNotification, object: UIDevice.current)
#else
        // TODO: monitor macOS battery
#endif
    }
    
    @objc func onDevicePackageReceived(np: NetworkPackage) -> Bool {
        if (np.type == .batteryRequest) {
            print("Battery plugin received a force update request")
            sendBatteryStatusOut()
            return true
        } else if (np.type == .battery) { // received battery info from other device
            print("Battery plugin received battery status from remote device")
            DispatchQueue.main.async { [self] in
                withAnimation {
                    self.remoteChargeLevel = np.integer(forKey: "currentCharge")
                    self.remoteIsCharging = np.bool(forKey: "isCharging")
                    self.remoteThresholdEvent = np.integer(forKey: "thresholdEvent")
                }
            }
            return true
        }
        return false
    }
    
    @objc func sendBatteryStatusOut() {
        let np: NetworkPackage = NetworkPackage(type: .battery)
#if !os(macOS)
        let batteryLevel: Int = Int(UIDevice.current.batteryLevel * 100)
        let batteryStatus = UIDevice.current.batteryState
        if (batteryStatus != .unknown) {
            let batteryThresholdEvent: Int = (batteryLevel < 10) ? 1 : 0
            np.setInteger(batteryLevel, forKey: "currentCharge")
            np.setBool((batteryStatus == .charging), forKey: "isCharging")
            np.setInteger(batteryThresholdEvent, forKey: "thresholdEvent")
            print("Battery status accessed successfully, sending out:")
            print("BatteryLevel=\(batteryLevel)")
            print("BatteryisCharging=\(batteryStatus == .charging)")
        } else {
            np.setInteger(0, forKey: "currentCharge")
            np.setBool(false, forKey: "isCharging")
            np.setInteger(0, forKey: "thresholdEvent")
            print("Battery status reported as unknown, reporting 0 for all values")
        }
#else
        let internalFinder = InternalFinder()
        if (internalFinder.batteryPresent) {
            let internalBattery = internalFinder.getInternalBattery()
            let batteryLevel = Int(internalBattery?.charge ?? 0)
            let acPowered: Bool = internalBattery?.acPowered ?? false
            if batteryLevel == self.batteryLevel && acPowered == self.acPowered {
                return
            }
            self.batteryLevel = batteryLevel
            self.acPowered = acPowered
            let batteryThresholdEvent: Int = (batteryLevel < 10) ? 1 : 0
            np.setInteger(Int(batteryLevel), forKey: "currentCharge")
            np.setBool((internalBattery?.acPowered ?? false), forKey: "isCharging")
            np.setInteger(batteryThresholdEvent, forKey: "thresholdEvent")
            print("Battery status accessed successfully, sending out:")
            print("BatteryLevel=\(batteryLevel)")
            print("BatteryisCharging=\(acPowered)")
        } else {
            np.setInteger(0, forKey: "currentCharge")
            np.setBool(false, forKey: "isCharging")
            np.setInteger(0, forKey: "thresholdEvent")
            print("Battery status reported as unknown, reporting 0 for all values")
        }
#endif
        controlDevice.send(np, tag: Int(PACKAGE_TAG_BATTERY))
    }
    
    @objc func sendBatteryStatusRequest() {
        let np: NetworkPackage = NetworkPackage(type: .batteryRequest)
        np.setBool(true, forKey: "request")
        controlDevice.send(np, tag: Int(PACKAGE_TAG_NORMAL))
    }
    
    var statusSFSymbolName: String {
        // TODO: display additional levels from SF Symbols 3
        if remoteThresholdEvent == 1 || remoteChargeLevel < 10 {
            return "battery.0"
        } else if remoteIsCharging {
            return "battery.100.bolt"
        } else if remoteChargeLevel >= 40 {
            return "battery.100"
        } else if remoteChargeLevel < 40 {
            return "battery.25"
        } else {
            return "camera.metering.unknown"
        }
    }
    
    var statusColor: Color {
        if remoteThresholdEvent == 1 || remoteChargeLevel < 10 {
            return .red
        } else if remoteIsCharging {
            return .green
        } else if remoteChargeLevel < 40 {
            return .yellow
        } else {
            return .primary
        }
    }
    
    // Global functions for setting up and responding to the device's own events when battery
    // status changes
    
#if !os(macOS)
    // When the state of the battery changes: plugged, unplugged, full charge, unknown
    @objc func batteryStateDidChange(notification: Notification) {
        sendBatteryStatusOut()
    }
    
    // When the percentage level of the battery changes
    @objc func batteryLevelDidChange(notification: Notification) {
        sendBatteryStatusOut()
    }
#endif
}

// Global functions for Battery handling
func startBatteryMonitoringAllDevices() {
    for device in backgroundService._devices.values {
        if (device.isPaired() && (device._pluginsEnableStatus[.batteryRequest] != nil) && (device._pluginsEnableStatus[.batteryRequest] as! Bool)) {
#if !os(macOS)
            (device._plugins[.batteryRequest] as! Battery).startBatteryMonitoring()
#endif
        }
    }
}

func broadcastBatteryStatusAllDevices() {
    for device in backgroundService._devices.values {
        if (device.isPaired() && (device._pluginsEnableStatus[.batteryRequest] != nil) && (device._pluginsEnableStatus[.batteryRequest] as! Bool)) {
            (device._plugins[.batteryRequest] as! Battery).sendBatteryStatusOut()
        }
    }
}

func requestBatteryStatusAllDevices() {
    for device in backgroundService._devices.values {
        if (device.isPaired() && (device._pluginsEnableStatus[.batteryRequest] != nil) && (device._pluginsEnableStatus[.batteryRequest] as! Bool)) {
            (device._plugins[.batteryRequest] as! Battery).sendBatteryStatusRequest()
        }
    }
}
