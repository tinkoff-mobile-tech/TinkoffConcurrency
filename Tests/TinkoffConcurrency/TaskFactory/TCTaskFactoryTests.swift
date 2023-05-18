import XCTest

import TinkoffConcurrency

final class TCTaskFactoryTests: XCTestCase {

    // MARK: - Dependencies

    private var taskFactory: TCTaskFactory!

    // MARK: - Private Static Properties

    @TaskLocal private static var testValue = 42

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()

        taskFactory = TCTaskFactory()
    }

    // MARK: - Tests

    func test_task_whenTaskCreated() async throws {
        // given
        let result = Int.fake()
        
        let task = TCTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.task {
                XCTAssertEqual(TCTaskFactoryTests.testValue, 999)

                return result
            }
        }
        
        // when
        let taskResult = await task.value

        // then
        XCTAssertEqual(taskResult, result)
    }

    func test_task_whenCreatedTaskThrows() async throws {
        // given
        let error = FakeErrors.default

        let task = TCTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.task {
                XCTAssertEqual(TCTaskFactoryTests.testValue, 999)

                throw error
            }
        }

        // when
        let result = await XCTExecuteThrowsError(try await task.value)

        // then
        XCTAssertEqualErrors(result, error)
    }

    func test_detached_whenTaskCreated() async throws {
        // given
        let result = Int.fake()
        
        let task = TCTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.detached {
                XCTAssertEqual(TCTaskFactoryTests.testValue, 42)
                
                return result
            }
        }
        
        // when
        let taskResult = await task.value

        // then
        XCTAssertEqual(taskResult, result)
    }

    func test_detached_whenCreatedTaskThrows() async throws {
        // given
        let error = FakeErrors.default

        let task = TCTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.detached {
                XCTAssertEqual(TCTaskFactoryTests.testValue, 42)

                throw error
            }
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
