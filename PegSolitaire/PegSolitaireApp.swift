//
//  PegSolitaireApp.swift
//  PegSolitaire
//
//  Created by Onno Speekenbrink on 2025-08-11.
//

import SwiftUI
import UIKit

@main
struct PegSolitaireApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Disable multi-touch globally by setting it on all windows
                    for scene in UIApplication.shared.connectedScenes {
                        guard let windowScene = scene as? UIWindowScene else { continue }
                        for window in windowScene.windows {
                            window.isMultipleTouchEnabled = false
                        }
                    }
                }
        }
    }
}
