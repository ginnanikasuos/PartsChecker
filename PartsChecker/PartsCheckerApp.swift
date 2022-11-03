//
//  PartsCheckerApp.swift
//  PartsChecker
//
//  Created by E.O on 2022/11/03.
//

import SwiftUI

@main
struct PartsCheckerApp: App {
    // ViewModel を　StateObject でインスタンス
    @StateObject private var vm = ViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task {
                    await vm.requestDataScannerAccessStatus()
                }
        }
    }
}
