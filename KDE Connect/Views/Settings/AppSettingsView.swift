//
//  AppSettingsView.swift
//  KDE Connect
//
//  Created by Ruixuan Tu on 2022/05/12.
//

import SwiftUI

enum AppIcon: RawRepresentable, CaseIterable {
    case `default`
    case classic
    case roundedRectangle
    
    init?(rawValue: String?) {
        switch rawValue {
        case nil:
            self = .default
        case "AppIcon-Classic":
            self = .classic
        case "AppIcon-RoundedRectangle":
            self = .roundedRectangle
        default:
            return nil
        }
    }
    
    var rawValue: String? {
        switch self {
        case .default:
            return nil
        case .classic:
            return "AppIcon-Classic"
        case .roundedRectangle:
            return "AppIcon-RoundedRectangle"
        }
    }
    
    var name: Text {
        switch self {
        case .default:
            return Text("Default")
        case .classic:
            return Text("Classic")
        case .roundedRectangle:
            return Text("Rounded Rectangle")
        }
    }
}

struct AppSettingsView: View {
    @EnvironmentObject var settings: SelfDeviceData
    @Binding var chosenTheme: String
    private let themes: [String] = ["System Default", "Light", "Dark"]
    @Binding var appIcon: AppIcon
    @State private var appIconName: String

    init(chosenTheme: Binding<String>, appIcon: Binding<AppIcon>) {
        self._chosenTheme = chosenTheme
        self._appIcon = appIcon
        self.appIconName = appIcon.wrappedValue.rawValue ?? "AppIcon"
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker(selection: $chosenTheme, label: Text("App Theme:")) {
                    ForEach(themes, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
                .horizontalRadioGroupLayout()
                Spacer()
            }
            HStack {
                Picker(selection: $appIconName, label: Text("App Icon:")) {
                    Text("Default").tag("AppIcon")
                    Text("Classic").tag("AppIcon-Classic")
                    Text("Rounded Rectangle").tag("AppIcon-RoundedRectangle")
                }
                .pickerStyle(RadioGroupPickerStyle())
                .horizontalRadioGroupLayout()
                .onChange(of: appIconName) { iconName in
                    settings.appIcon = AppIcon(rawValue: (iconName == "AppIcon" ? nil : iconName))!
                    NSApplication.shared.applicationIconImage = NSImage(named: appIconName)
                }
                Spacer()
            }
            HStack {
                Text("Preview: ")
                Image(nsImage: NSImage(named: appIconName)!)
                Spacer()
            }
        }.padding(.all)
    }
}

struct AppSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppSettingsView(chosenTheme: .constant("System Default"), appIcon: .constant(AppIcon(rawValue: nil)!))
    }
}
