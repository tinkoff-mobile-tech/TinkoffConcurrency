import protocol Combine.Cancellable

/// Suspends the current task, then calls the given closure with a checked throwing continuation for the current task. If given closure returns a cancellable,
/// it will be called if task is cancelled. If calling task is cancelled, the continuation is resumed throwing ``CancellationError`` exception.
///
/// - Parameters:
///   - body: a closure that will be called and given `completion` closure as a parameter. When task is done, a `completion` must be called with either
///           execution result or failure reason
/// - Throws: an error if it is received from `body`
/// - Returns: a result that `body` passed to `completion` upon ready.
public func withCheckedThrowingCancellableContinuation<T>(function: String = #function, _ body: (@escaping (Result<T, Error>) -> Void) -> Cancellable?) async throws -> T {
    // We store all cancellables in a storage that will guarantee that continuation will be resumed exactly once
    let cancellablesStorage = CancellablesStorage()

    return try await withTaskCancellationHandler {
        // If task has been already cancelled, bailing out early.
        if cancellablesStorage.state == CancellablesStorage.State.cancelled {
            throw CancellationError()
        }

        return try await withCheckedThrowingContinuation(function: function) { continuation in
            // Call body and add a cancellable to the storage. If task cancellation handler is called,
            // this cancellable will be called and all other interactions with the storage will be ignored

            let cancellable = body { result in
                // Here, asynchronous task is finished, but we still have a race possibility if cancel is called
                // from another thread. To get over that, we deactivate a storage, so it will ignore all calls to
                // `cancel` or `deactivate`, and `deactivate` itself is atomic. If deactivation succeds, we can resume
                // continuation with execution result.
                guard cancellablesStorage.deactivate() else {
                    return
                }

                continuation.resume(with: result)
            }

            cancellablesStorage.add(CancellableClosure {
                cancellable?.cancel()
                continuation.resume(throwing: CancellationError())
            })
        }
    } onCancel: {
        // If task is cancelled, this handler is called synchronously from the thread that initiated cancellation.
        // We just cancel our storage, and, since this operation is atomic, it either cancels current operation
        // or does nothing if storage was deactivated from another thread.
        cancellablesStorage.cancel()
    }
}
