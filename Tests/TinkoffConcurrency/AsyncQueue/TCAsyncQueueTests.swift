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

    func test_asyncQueue_enqueue() async throws {
        // given
        let expectation1 = expectation(description: "operation 1")
        let expectation2 = expectation(description: "operation 2")
        let expectation3 = expectation(description: "operation 3")

        let result = UncheckedSendable([Int]())

        let queue = TCAsyncQueue(taskFactory: taskFactory)

        await queue.enqueue {
            await XCTWaiter.waitAsync(for: [expectation1], timeout: 1)
            result.mutate { $0.append(1) }
        }

        await queue.enqueue {
            await XCTWaiter.waitAsync(for: [expectation2], timeout: 1)
            result.mutate { $0.append(2) }
        }

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
}
