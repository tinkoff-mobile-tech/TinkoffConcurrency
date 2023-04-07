import Foundation

/// Type erasure for ITask
public struct AnyTask<Value: Sendable, Failure: Error>: ITask {
    
    // MARK: - Public Properties
    
    public var value: Value {
        get async throws {
            try await _value()
        }
    }
    
    // MARK: - Private Properties
    
    private let _value: @Sendable () async throws -> Value
    private let _cancel: @Sendable () -> Void

    // MARK: - Initializers
    
    public init<T: ITask>(_ value: T) where T.Value == Value, T.Failure == Failure {
        _value = { @Sendable in try await value.value }
        _cancel = { @Sendable in value.cancel() }
    }
    
    // MARK: - Public Methods
    
    public func cancel() {
        _cancel()
    }
}

extension ITask {
    public func erased() -> AnyTask<Value, Failure> {
        AnyTask(self)
    }
}
