//
//  TinkoffConcurrencyApp.swift
//  TinkoffConcurrency
//
//  Created by Aleksandr Darovskikh on 08.12.2022.
//

import SwiftUI

@main
struct TinkoffConcurrencyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(model: ExampleModel())
        }
    }
}
