import XCTest

@testable import TinkoffConcurrency

final class WithCheckedThrowingCancellableContinuationTests: XCTestCase {

    // MARK: - Tests

    func test_withCheckedThrowingCancellableContinuation_whenBodyCompletionResultIsSuccess() async {
        // given
        let cancellable = TCCancellableMock()

        let bodyCompletionResult = String.fake()

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                completion(Result.success(bodyCompletionResult))

                return cancellable
            }
        }

        let result = await XCTExecuteThrowsNoError(try await task.value)

        // then
        XCTAssertEqual(result, bodyCompletionResult)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenBodyCompletionResultIsFailure() async {
        // given
        let cancellable = TCCancellableMock()

        let bodyCompletionResult = FakeErrors.default

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                completion(Result.failure(bodyCompletionResult))

                return cancellable
            }
        }

        let resultError = await XCTExecuteThrowsError(
            try await task.value
        )

        // then
        XCTAssertEqualErrors(resultError, bodyCompletionResult)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled() async {
        // given
        let taskStartExpectation = expectation(description: "taskStartExpectation")

        let cancellable = TCCancellableMock()

        // when
        let task = Task {
            await XCTWaiter.waitAsync(for: [taskStartExpectation], timeout: 10)

            _ = try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                completion(Result.success(String.fake()))

                return cancellable
            }
        }

        task.cancel()

        taskStartExpectation.fulfill()

        await XCTExecuteCancels(
            try await task.value
        )

        // then
        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled_whenBodyCompletionInProgress() async {
        // given
        let bodyStartedExpectation = expectation(description: "bodyStartedExpectation")
        let bodyCompletedExpectation = expectation(description: "bodyCompletedExpectation")

        let cancellable = TCCancellableMock()

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                bodyStartedExpectation.fulfill()

                DispatchQueue.global().async {
                    _ = XCTWaiter.wait(for: [bodyCompletedExpectation], timeout: 10)

                    completion(Result.success(String.fake()))
                }

                return cancellable
            }
        }

        await XCTWaiter.waitAsync(for: [bodyStartedExpectation], timeout: 10)

        task.cancel()

        bodyCompletedExpectation.fulfill()

        await XCTExecuteCancels(
            try await task.value
        )

        // then
        XCTAssertTrue(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled_whenBodyCompletionIsCompleted() async {
        // given
        let bodyCompletionStartExpectation = expectation(description: "bodyCompletionStartExpectation")
        let bodyCompletionCompletedExpectation = expectation(description: "bodyCompletionCompletedExpectation")

        let cancellable = TCCancellableMock()

        let bodyCompletionResult = String.fake()

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                DispatchQueue.global().async {
                    bodyCompletionStartExpectation.fulfill()

                    completion(Result.success(bodyCompletionResult))

                    _ = XCTWaiter.wait(for: [bodyCompletionCompletedExpectation], timeout: 10)
                }

                return cancellable
            }
        }

        await XCTWaiter.waitAsync(for: [bodyCompletionStartExpectation], timeout: 10)

        bodyCompletionCompletedExpectation.fulfill()

        task.cancel()

        let result = await XCTExecuteThrowsNoError(
            try await task.value
        )

        // then
        XCTAssertEqual(result, bodyCompletionResult)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled_whenCancellationHasntBeenAddedToStorageYet() async {
        // given
        let cancellable = TCCancellableMock()

        var task: Task<String, Error>!

        let continuation = { (completion: @escaping (Result<String, Error>) -> Void) -> TCCancellable in
            task.cancel()

            completion(Result.success(String.fake()))

            return cancellable
        }

        // when
        task = Task {
            try await withCheckedThrowingCancellableContinuation(continuation)
        }

        await XCTExecuteCancels(
            try await task.value
        )

        // then
        XCTAssertTrue(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_cancellableRetainCycle() async {
        // given
        let processor = RetainingCancellableProcessor()
        var task: Task<Void, Error>!
        let cancellableIsDeinited = UncheckedSendable(false)

        // when
        task = Task {
            try await withCheckedThrowingCancellableContinuation { completion in
                return processor.performJob(
                    shouldFinish: true,
                    completion: completion,
                    onDeinit: { cancellableIsDeinited.mutate { $0 = true } }
                )
            }
        }

        await XCTExecuteThrowsNoError(
            try await task.value
        )

        // then
        XCTAssertTrue(cancellableIsDeinited.value)
    }

    func test_withCheckedThrowingCancellableContinuation_cancellableRetainCycle_whenTaskIsCancelled() async {
        // given
        let bodyCompletionStartExpectation = expectation(description: "bodyCompletionStartExpectation")
        let processor = RetainingCancellableProcessor()
        var task: Task<Void, Error>!
        let cancellableIsDeinited = UncheckedSendable(false)

        // when
        task = Task {
            try await withCheckedThrowingCancellableContinuation { completion in
                bodyCompletionStartExpectation.fulfill()

                return processor.performJob(
                    shouldFinish: false,
                    completion: completion,
                    onDeinit: { cancellableIsDeinited.mutate { $0 = true } }
                )
            }
        }

        await XCTWaiter.waitAsync(for: [bodyCompletionStartExpectation], timeout: 1)

        task.cancel()

        await XCTExecuteCancels(
            try await task.value
        )

        // then
        XCTAssertTrue(cancellableIsDeinited.value)
    }
}
