//
//  PhotonDemoApp.swift
//  JPhotonDemoDemo
//
//  Created by Kevin Ladan on 7/8/23.
//

import SwiftUI
import Photon

struct Stamp: Codable, Hashable {
    let stamp: Int
    let tx_hash: String
    let stamp_url: String
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct PhotonDemoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
