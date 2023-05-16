import XCTest

import TinkoffConcurrency
import TinkoffConcurrencyTesting

final class TCAsyncQueueTests: XCTestCase {

    // MARK: - Dependencies

    private var taskFactory: TCTestTaskFactory!

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()

        taskFactory = TCTestTaskFactory()
    }

    // MARK: - Tests

    func test_asyncQueue_enqueue_order() async throws {
        // given
        let expectation1 = expectation(description: "operation 1")
        let expectation2 = expectation(description: "operation 2")
        let expectation3 = expectation(description: "operation 3")

        let result = UncheckedSendable([Int]())

        let queue = TCAsyncQueue(taskFactory: taskFactory)

        // throwing operation that throws
        await queue.enqueue {
            await XCTWaiter.waitAsync(for: [expectation1], timeout: 1)

            result.mutate { $0.append(1) }

            throw FakeErrors.default
        }

        // throwing operation that returns value
        await queue.enqueue {
            await XCTWaiter.waitAsync(for: [expectation2], timeout: 1)

            try throwingHelper()

            result.mutate { $0.append(2) }
        }

        // non-throwing operation
        await queue.enqueue {
            await XCTWaiter.waitAsync(for: [expectation3], timeout: 1)

            result.mutate { $0.append(3) }
        }

        // when
        expectation3.fulfill()
        expectation2.fulfill()
        expectation1.fulfill()

        await taskFactory.runUntilIdle()

        // then
        XCTAssertEqual(result.value, [1, 2, 3])
    }

    func test_asyncQueue_enqueue_result() async throws {
        // given
        let queue = TCAsyncQueue(taskFactory: taskFactory)

        let queueEnqueueResult = String.fake()

        // when
        let task = await queue.enqueue {
            queueEnqueueResult
        }

        await taskFactory.runUntilIdle()

        let result = await task.value

        // then
        XCTAssertEqual(result, queueEnqueueResult)
    }

    func test_asyncQueue_throwingEnqueue_result() async throws {
        // given
        let queue = TCAsyncQueue(taskFactory: taskFactory)

        let queueEnqueueResult = String.fake()

        // when
        let task = await queue.enqueue {
            try throwingHelper()
            return queueEnqueueResult
        }

        await taskFactory.runUntilIdle()

        let result = try await task.value

        // then
        XCTAssertEqual(result, queueEnqueueResult)
    }

    func test_asyncQueue_throwingEnqueue_throwing() async throws {
        // given
        let queue = TCAsyncQueue(taskFactory: taskFactory)

        let queueEnqueueResult = FakeErrors.default

        // when
        let task = await queue.enqueue {
            throw queueEnqueueResult
        }

        await taskFactory.runUntilIdle()

        let result = await XCTExecuteThrowsError(try await task.value)!

        // then
        XCTAssertEqualErrors(result, queueEnqueueResult)
    }
}

private func throwingHelper() throws {}
