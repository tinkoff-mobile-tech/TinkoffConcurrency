//
//  ViewController.swift
//  TinkoffConcurrency
//
//  Created by Aleksandr Darovskikh on 12/08/2022.
//  Copyright (c) 2022 Aleksandr Darovskikh. All rights reserved.
//


import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ExampleModel

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: model.progress)

            Text(model.stateDescription)

            WideButton(title: "Run cancellable task") {
                model.runCancellableTask()
            }
            .disabled(model.isRunning)

            WideButton(title: "Run uncancellable task") {
                model.runUncancellableTask()
            }
            .disabled(model.isRunning)

            WideButton(title: "Run Continuation") {
                model.runContinuation()
            }
            .disabled(model.isRunning)

            WideButton(title: "Cancel") {
                model.cancel()
            }
            .disabled(!model.isRunning)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: ExampleModel())
    }
}

struct WideButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
