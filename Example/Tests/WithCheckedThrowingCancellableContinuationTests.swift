import XCTest
import protocol Combine.Cancellable
@testable import TinkoffConcurrency

final class WithCheckedThrowingCancellableContinuationTests: XCTestCase {

    // MARK: - Tests

    func test_withCheckedThrowingCancellableContinuation_whenBodyCompletionResultIsSuccess() async {
        // given
        let cancellable = CancellableMock()

        let bodyCompletionResult = String.fake()

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                completion(Result.success(bodyCompletionResult))

                return cancellable
            }
        }

        let resultResult = await XCTExecuteThrowsNoError(try await task.value)

        // then
        XCTAssertEqual(resultResult, bodyCompletionResult)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenBodyCompletionResultIsFailure() async {
        // given
        let cancellable = CancellableMock()

        let bodyCompletionResult = FakeErrors.default

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                completion(Result.failure(bodyCompletionResult))

                return cancellable
            }
        }

        let resultError = await XCTExecuteThrowsError(try await task.value)

        // then
        XCTAssertEqualErrors(resultError, bodyCompletionResult)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled() async {
        // given
        // Ожидание начала выполнения задачи.
        let taskStartExpectation = expectation(description: "taskStartExpectation")

        let cancellable = CancellableMock()

        // when
        let task = Task {
            // Оттягиваем начало выполнения задачи, чтобы гарантировать, что задача будет отменена до начала выполнения переданного замыкания.
            await XCTWaiter.waitAsync(for: [taskStartExpectation], timeout: 10)

            _ = try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                completion(Result.success(String.fake()))

                return cancellable
            }
        }

        task.cancel()

        taskStartExpectation.fulfill()

        await XCTExecuteCancels(try await task.value)

        // then
        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled_whenBodyCompletionInProgress() async {
        // given
        // Ожидание начала выполнения переданного замыкания.
        let bodyStartedExpectation = expectation(description: "bodyStartedExpectation")

        // Ожидание окончания выполнения переданного замыкания.
        let bodyCompletedExpectation = expectation(description: "bodyCompletedExpectation")

        let cancellable = CancellableMock()

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                bodyStartedExpectation.fulfill()

                DispatchQueue.global().async {
                    // Оттягиваем окончание выполнения переданного замыкания, чтобы гарантировать, что задача отменится в момент выполнения.
                    _ = XCTWaiter.wait(for: [bodyCompletedExpectation], timeout: 10)

                    completion(Result.success(String.fake()))
                }

                return cancellable
            }
        }

        // Ожидаем начало выполнения переданного замыкания, чтобы гарантировать, что задача отменится в момент выполнения.
        await XCTWaiter.waitAsync(for: [bodyStartedExpectation], timeout: 10)

        task.cancel()

        bodyCompletedExpectation.fulfill()

        await XCTExecuteCancels(try await task.value)

        // then
        XCTAssertTrue(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled_whenBodyCompletionIsCompleted() async {
        // given
        // Ожидание начала выполнения замыкания внутри переданного замыкания.
        let bodyCompletionStartExpectation = expectation(description: "bodyCompletionStartExpectation")

        // Ожидание окончания выполнения замыкания внутри переданного замыкания.
        let bodyCompletionCompletedExpectation = expectation(description: "bodyCompletionCompletedExpectation")

        let cancellable = CancellableMock()

        let bodyCompletionResult = String.fake()

        // when
        let task = Task {
            try await withCheckedThrowingCancellableContinuation { (completion: @escaping (Result<String, Error>) -> Void) in
                DispatchQueue.global().async {
                    bodyCompletionStartExpectation.fulfill()

                    completion(Result.success(bodyCompletionResult))

                    // Оттягиваем окончание выполнения замыкания внутри переданного замыкания, чтобы гарантировать, что задача отменится после окончания выполнения замыкания.
                    _ = XCTWaiter.wait(for: [bodyCompletionCompletedExpectation], timeout: 10)
                }

                return cancellable
            }
        }

        // Ожидаем начало выполнения переданного замыкания, чтобы гарантировать, что задача отменится после окончания выполнения замыкания.
        await XCTWaiter.waitAsync(for: [bodyCompletionStartExpectation], timeout: 10)

        bodyCompletionCompletedExpectation.fulfill()

        task.cancel()

        let resultResult = await XCTExecuteThrowsNoError(try await task.value)

        // then
        XCTAssertEqual(resultResult, bodyCompletionResult)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_withCheckedThrowingCancellableContinuation_whenTaskIsCancelled_whenCancellationHaventBeenAddedToStorageYet() async {
        // given
        let cancellable = CancellableMock()

        var task: Task<String, Error>!

        let continuation = { (completion: @escaping (Result<String, Error>) -> Void) -> Cancellable in
            task.cancel()

            completion(Result.success(String.fake()))

            return cancellable
        }

        // when
        task = Task {
            try await withCheckedThrowingCancellableContinuation(continuation)
        }

        await XCTExecuteCancels(try await task.value)

        // then
        XCTAssertTrue(cancellable.invokedCancel)
    }
}
