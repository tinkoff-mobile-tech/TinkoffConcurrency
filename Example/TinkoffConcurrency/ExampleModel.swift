//
//  ViewController.swift
//  TinkoffConcurrency
//
//  Created by Aleksandr Darovskikh on 12/08/2022.
//  Copyright (c) 2022 Aleksandr Darovskikh. All rights reserved.
//

import SwiftUI
import Combine
import TinkoffConcurrency

@MainActor
class ExampleModel: ObservableObject {

    // MARK: - Model

    enum State {
        case idle

        case running(task: Task<Void, Error>)

        case finished(result: String)

        case interrupted
    }

    @Published var progress: Double = 0.0
    @Published var state: State = .idle

    // MARK: - ViewModel

    var isRunning: Bool {
        if case .running(_) = state {
            return true
        }

        return false
    }

    var stateDescription: String {
        switch state {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .finished(let result):
            return "Finished: \(result)"
        case .interrupted:
            return "Interrupted"
        }
    }

    private func runThrowingClosure(_ closure: @escaping () async throws -> String) {
        guard !isRunning else { return }

        storedCancellable?.cancel()
        storedCancellable = nil

        switch state {
        case .idle, .finished, .interrupted:
            state = .running(task: Task {
                do {
                    let result = try await closure()
                    state = .finished(result: result)
                } catch {
                    state = .interrupted
                }
            })
        default:
            break
        }
    }

    func runCancellableTask() {
        runThrowingClosure {
            try await self.exampleCancellableTask(duration: 5)
        }
    }

    func runNonCancellableTask() {
        runThrowingClosure {
            try await self.exampleNonCancellableTask(duration: 5)
        }
    }

    func runContinuation() {
        runThrowingClosure {
            try await self.exampleContinuation(duration: 5)
        }
    }

    func cancel() {
        if case .running(let task) = state {
            task.cancel()
        }
    }

    // MARK: - Example Task

    /// Пример задачи, имитирующей бурную деятельность в течение заданного времени, а затем вызывающей замыкание
    func exampleTask(duration: Double, completion: @escaping (Result<String, Error>) -> Void) -> TCCancellable {
        let startDate = Date()

        Timer.publish(every: 0.1, on: .main, in: .default)
            .autoconnect()
            .map { _ in -startDate.timeIntervalSinceNow / duration }
            .prefix(while: { $0 <= 1 })
            .append(1.0)
            .sink { _ in
                completion(.success("done in \(duration) seconds"))
            } receiveValue: { [weak self] value in
                self?.progress = value
            }
        
        return TCCancellableClosure { }
    }

    // MARK: - Wrapping Variants

    /// Пример оборачивания задачи, поддерживающей отмену
    func exampleCancellableTask(duration: Double) async throws -> String {
        try await withCheckedThrowingCancellableContinuation { completion in
            exampleTask(duration: duration, completion: completion)
        }
    }

    /// Пример оборачивания задачи, не поддерживающей отмену
    private var storedCancellable: TCCancellable?
    
    func exampleNonCancellableTask(duration: Double) async throws -> String {
        try await withCheckedThrowingCancellableContinuation { completion in
            storedCancellable = exampleTask(duration: duration, completion: completion)

            return nil
        }
    }

    func exampleContinuation(duration: Double) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            storedCancellable = exampleTask(duration: duration) { result in
                continuation.resume(with: result)
            }
        }
    }
}
