/*
 * SPDX-FileCopyrightText: 2021 Lucas Wang <lucas.wang@tuta.io>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

// Original header below:
//
//  ContentView.swift
//  KDE Connect Test
//
//  Created by Lucas Wang on 2021-06-17.
//

import SwiftUI

struct MainTabView: View {
    
    var body: some View {
        TabView {
            NavigationView {
                DevicesView()
            }
            .tabItem {
                Label("Devices", systemImage: "laptopcomputer.and.iphone")
            }
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

//struct TabView_Previews: PreviewProvider {
//    static var previews: some View {
//        MainTabView()
//    }
//}