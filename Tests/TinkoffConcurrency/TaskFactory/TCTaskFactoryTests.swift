import XCTest

import TinkoffConcurrency

final class TCTaskFactoryTests: XCTestCase {

    // MARK: - Dependencies

    private var taskFactory: TCTaskFactory!

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()

        taskFactory = TCTaskFactory()
    }

    // MARK: - Tests

    func test_taskStarted_whenTaskCreated() async throws {
        // given
        let result = Int.fake()
        
        let task = taskFactory.task {
            return result
        }
        
        // when
        let taskResult = await task.value

        // then
        XCTAssertEqual(taskResult, result)
    }

    func test_runUntilIdle_whenCreatedTaskThrows() async throws {
        // given
        let error = FakeErrors.default

        let task = taskFactory.task {
            throw error
        }

        // when
        let result = await XCTExecuteThrowsError(try await task.value)

        // then
        XCTAssertEqualErrors(result, error)
    }

    @MainActor func test_inheritedActorContext_whenTaskCreated() async throws {
        // given
        @MainActor func foo() {}

        // when
        taskFactory.task {
            // then
            foo()
        }
    }
}
