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
        let url1 = URL(string: "https://stampchain.io/api/stamps?page=1&page_size=14089&sort_order=asc")!
        let url2 = URL(string: "https://stampchain.io/api/stamps?stamp_begin=0&stamp_end=1000")!
        let photon = Photon<Stamp>()
        photon.stream(for: url1) { stamps in
            print("🟣 count: \(stamps.count)")
        } completionBlock: {
            print("🟣 complete!")
        }
        photon.stream(for: url2) { stamps in
            print("🟢 count: \(stamps.count)")
        } completionBlock: {
            print("🟢 complete!")
        }
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
