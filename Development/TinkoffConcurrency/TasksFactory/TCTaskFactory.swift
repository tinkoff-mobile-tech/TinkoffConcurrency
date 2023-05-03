import Foundation

/// Protocol for abstraction creating asynchronous tasks
public protocol ITCTaskFactory {
    
    // MARK: - Methods

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
    ) -> Task<T, Error>
}

public extension ITCTaskFactory {

    // MARK: - Methods

    @discardableResult
    func task<T: Sendable>(
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        task(priority: nil, operation: operation)
    }
}

/// Abstraction factory for creating asynchronous tasks
public struct TCTaskFactory: ITCTaskFactory {
    
    // MARK: - ITCTaskFactory

    public func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        Task(priority: priority, operation: operation)
    }
}
