import Foundation

/// Unit of an asynchronous work
public protocol ITask<Value, Failure>: Sendable, TCCancellable {
    associatedtype Value: Sendable
    associatedtype Failure: Error

    /// Awaited result of work
    var value: Value { get async throws }
}

// MARK: - ITask

extension Task: ITask {}
