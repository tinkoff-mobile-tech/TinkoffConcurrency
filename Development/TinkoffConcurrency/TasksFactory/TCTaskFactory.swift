import Foundation

/// Protocol for abstraction running asynchronous tasks.
///
/// Use it as a controlled dependency when "fire and forget" operations are required. See <doc:TaskManagement> for details.
public protocol ITCTaskFactory {
    
    // MARK: - Methods
    
    /// Runs the given throwing operation asynchronously as part of a new top-level task on behalf of the current actor.
    ///
    /// Use this function when creating asynchronous work that operates on behalf of the synchronous function that calls it.
    /// Like ``detached(priority:operation:)-96bex``, this function creates a separate, top-level task. Unlike ``detached(priority:operation:)-96bex``,
    /// the task created by ``task(priority:operation:)-9y2yp`` inherits the priority and actor context of the caller, so the operation is
    /// treated more like an asynchronous extension to the synchronous operation.
    /// You need to keep a reference to the task if you want to cancel it by calling the
    /// [Task.cancel()](https://developer.apple.com/documentation/swift/task/cancel()) method.
    /// Discarding your reference to a detached task doesn’t implicitly cancel that task, it only makes it impossible
    /// for you to explicitly cancel the task.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///   - operation: The operation to perform. Note that `@_inheritActorContext` is used to inherit the actor context from a call site.
    /// - Returns: A reference to the task.
    @discardableResult
    func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error>
    
    /// Runs the given nonthrowing operation asynchronously as part of a new top-level task on behalf of the current actor.
    ///
    /// Use this function when creating asynchronous work that operates on behalf of the synchronous function that calls it.
    /// Like ``detached(priority:operation:)-7jwod``, this function creates a separate, top-level task.
    /// Unlike ``detached(priority:operation:)-7jwod``, the task created by ``task(priority:operation:)-4opq8``
    /// inherits the priority and actor context of the caller, so the operation is treated more like an asynchronous extension to the synchronous operation.
    /// You need to keep a reference to the task if you want to cancel it by calling the
    /// [Task.cancel()](https://developer.apple.com/documentation/swift/task/cancel()) method.
    /// Discarding your reference to a detached task doesn’t implicitly cancel that task, it only makes it impossible for you to explicitly cancel the task.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from `Task.currentPriority`.
    ///   - operation: The operation to perform. Note that `@_inheritActorContext` is used to inherit the actor context from a call site.
    /// - Returns: A reference to the task.
    @discardableResult
    func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async -> T
    ) -> Task<T, Never>
    
    /// Runs the given throwing operation asynchronously as part of a new top-level task.
    ///
    /// Don’t use a detached task if it’s possible to model the operation using structured concurrency features like child tasks.
    /// Child tasks inherit the parent task’s priority and task-local storage, and canceling a parent task automatically cancels all of its child tasks.
    /// You need to handle these considerations manually with a detached task. You need to keep a reference to the detached task if you want to cancel
    /// it by calling the [Task.cancel()](https://developer.apple.com/documentation/swift/task/cancel()) method. Discarding your reference
    /// to a detached task doesn’t implicitly cancel that task, it only makes it impossible for you to explicitly cancel the task.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from `Task.currentPriority`.
    ///   - operation: The operation to perform.
    /// - Returns: A reference to the task.
    @discardableResult
    func detached<T: Sendable>(
        priority: TaskPriority?,
        operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error>
    
    /// Runs the given nonthrowing operation asynchronously as part of a new top-level task.
    ///
    /// Don’t use a detached task if it’s possible to model the operation using structured concurrency features like child tasks.
    /// Child tasks inherit the parent task’s priority and task-local storage, and canceling a parent task automatically cancels all of its child tasks.
    /// You need to handle these considerations manually with a detached task. You need to keep a reference to the detached task if you want to cancel
    /// it by calling the [Task.cancel()](https://developer.apple.com/documentation/swift/task/cancel()) method. Discarding your reference
    /// to a detached task doesn’t implicitly cancel that task, it only makes it impossible for you to explicitly cancel the task.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task. Pass nil to use the priority from `Task.currentPriority`.
    ///   - operation: The operation to perform.
    /// - Returns: A reference to the task.
    @discardableResult
    func detached<T: Sendable>(
        priority: TaskPriority?,
        operation: @escaping @Sendable () async -> T
    ) -> Task<T, Never>
}

public extension ITCTaskFactory {
    
    // MARK: - Methods
    
    @discardableResult
    func task<T: Sendable>(
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        task(priority: nil, operation: operation)
    }
    
    @discardableResult
    func task<T: Sendable>(
        @_inheritActorContext operation: @escaping @Sendable () async -> T
    ) -> Task<T, Never> {
        task(priority: nil, operation: operation)
    }
    
    @discardableResult
    func detached<T: Sendable>(
        operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        detached(priority: nil, operation: operation)
    }
    
    @discardableResult
    func detached<T: Sendable>(
        operation: @escaping @Sendable () async -> T
    ) -> Task<T, Never> {
        detached(priority: nil, operation: operation)
    }
}

/// Abstraction factory for running asynchronous tasks.
///
/// Use it as a controlled dependency in production code.
/// It just wraps existing [Task(priority:operation)](https://developer.apple.com/documentation/swift/task/init(priority:operation:)-5ltye)
/// and [Task.detached(priority:operation)](https://developer.apple.com/documentation/swift/task/detached(priority:operation:)-3lvix)
/// without any changes. See <doc:TaskManagement> for details.
public struct TCTaskFactory: ITCTaskFactory {
    
    // MARK: - Initializers
    
    public init() {}
    
    // MARK: - ITCTaskFactory
    
    public func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        Task(priority: priority, operation: operation)
    }
    
    public func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async -> T
    ) -> Task<T, Never> {
        Task(priority: priority, operation: operation)
    }
    
    public func detached<T: Sendable>(
        priority: TaskPriority?,
        operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        Task.detached(priority: priority, operation: operation)
    }
    
    public func detached<T: Sendable>(
        priority: TaskPriority?,
        operation: @escaping @Sendable () async -> T
    ) -> Task<T, Never> {
        Task.detached(priority: priority, operation: operation)
    }
}
