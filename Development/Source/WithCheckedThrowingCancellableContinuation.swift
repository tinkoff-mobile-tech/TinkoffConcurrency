/// Suspends the current task, then calls the given closure with a completion.
///
/// This function uses a checked throwing continuation for the current task and ensures that it is resumed only once.
/// It also supports cooperative task cancelation, so if the given closure returns a cancellable operation, it will be cancelled
/// once the current task is cancelled.
///
/// - Parameters:
///   - function: A string identifying the declaration that is the notional source for the continuation, used to
///               identify the continuation in runtime diagnostics related to misuse of this continuation.
///   - body: The closure that will be called and given completion.
/// - Throws: An error passed to a completion by the given closure, or ``CancellationError`` if
///           the current task was cancelled before the given closure called a completion.
/// - Returns: A result passed to a completion by the given closure.
public func withCheckedThrowingCancellableContinuation<T>(
    function: String = #function,
    _ body: (@escaping (Result<T, Error>) -> Void) -> TCCancellable?) async throws -> T {
    let cancellablesStorage = TCCancellablesStorage()

    return try await withTaskCancellationHandler {
        if cancellablesStorage.state == TCCancellablesStorage.State.cancelled {
            throw CancellationError()
        }

        return try await withCheckedThrowingContinuation(function: function) { continuation in
            let cancellable = body { result in
                guard cancellablesStorage.deactivate() else {
                    return
                }

                continuation.resume(with: result)
            }

            cancellablesStorage.add(TCCancellableClosure {
                cancellable?.cancel()

                continuation.resume(throwing: CancellationError())
            })
        }
    } onCancel: {
        cancellablesStorage.cancel()
    }
}
