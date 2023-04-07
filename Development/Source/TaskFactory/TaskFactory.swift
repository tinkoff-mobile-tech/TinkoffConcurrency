import Foundation

/// Protocol for abstraction creating asynchronous tasks
public protocol ITaskFactory {
    /// Create asynchronous task.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///   - operation: The operation to perform. Note that `@_inheritActorContext` is used to inherit the actor context from a call site.
    /// - Returns: type erasured asynchronous task.
    @discardableResult
    func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> AnyTask<T, Error>
}

public extension ITaskFactory {
    @discardableResult
    func task<T: Sendable>(
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> AnyTask<T, Error> {
        task(priority: nil, operation: operation)
    }
}

/// Abstraction factory for creating asynchronous tasks
public struct TaskFactory: ITaskFactory {
    public func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> AnyTask<T, Error> {
        Task(priority: priority, operation: operation).erased()
    }
}
