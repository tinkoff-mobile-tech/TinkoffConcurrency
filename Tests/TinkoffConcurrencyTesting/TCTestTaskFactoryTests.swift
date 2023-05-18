import XCTest

import TinkoffConcurrencyTesting

final class TCTestTaskFactoryTests: XCTestCase {

    // MARK: - Dependencies

    private var taskFactory: TCTestTaskFactory!    
    
    // MARK: - Private Static Properties

    @TaskLocal private static var testValue = 42

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()
        taskFactory = TCTestTaskFactory()
    }

    // MARK: - Tests

    func test_taskStarted_whenTaskCreated() async {
        // given
        let result = Int.fake()
        
        let isTaskStarted = UncheckedSendable(false)
        
        // when
        let task = TCTestTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.task {
                isTaskStarted.mutate { $0 = true }
                
                XCTAssertEqual(TCTestTaskFactoryTests.testValue, 999)
                
                return result
            }
        }
        let taskResult = await task.value
        
        // then
        XCTAssertTrue(isTaskStarted.value)
        
        XCTAssertEqual(taskResult, result)
    }

    func test_taskStarted_whenDetachedTaskCreated() async {
        // given
        let result = Int.fake()
        
        let isTaskStarted = UncheckedSendable(false)
                
        // when
        let task = TCTestTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.detached {
                isTaskStarted.mutate { $0 = true }
                
                XCTAssertEqual(TCTestTaskFactoryTests.testValue, 42)

                return result
            }
        }
        let taskResult = await task.value

        // then
        XCTAssertTrue(isTaskStarted.value)
        
        XCTAssertEqual(taskResult, result)
    }
    
    func test_taskStarted_whenThrowingTaskCreated() async throws {
        // given
        let result = FakeErrors.default

        let isTaskStarted = UncheckedSendable(false)
        
        // when
        let task = TCTestTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.task {
                isTaskStarted.mutate { $0 = true }
                                
                XCTAssertEqual(TCTestTaskFactoryTests.testValue, 999)
                
                throw result
            }
        }
        let error = await XCTExecuteThrowsError(try await task.value)
        
        // then
        XCTAssertTrue(isTaskStarted.value)
        
        XCTAssertEqualErrors(error, result)
    }

    func test_taskStarted_whenThrowingDetachedTaskCreated() async throws {
        // given
        let result = FakeErrors.default

        let isTaskStarted = UncheckedSendable(false)
                
        // when
        let task = TCTestTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.detached {
                isTaskStarted.mutate { $0 = true }

                XCTAssertEqual(TCTestTaskFactoryTests.testValue, 42)
                
                throw result
            }
        }
        let error = await XCTExecuteThrowsError(try await task.value)

        // then
        XCTAssertTrue(isTaskStarted.value)

        XCTAssertEqualErrors(error, result)
    }

    func test_runUntilIdle_whenCreatedSeveralTasks() async throws {
        // given
        let tasksCount = 3
        let finishedTasksCount = UncheckedSendable(0)

        // when
        for _ in 0..<tasksCount {
            taskFactory.task {
                finishedTasksCount.mutate { $0 += 1 }
            }
            taskFactory.detached {
                finishedTasksCount.mutate { $0 += 1 }
            }
        }
        await taskFactory.runUntilIdle()
        
        // then
        XCTAssertEqual(finishedTasksCount.value, tasksCount * 2)
    }
    
    func test_runUntilIdle_whenCreatedInternalTaskInRunningAsynchronousWork() async throws {
        // given
        let finishedTasksCount = UncheckedSendable(0)
        
        let taskFactory = self.taskFactory!

        // when
        taskFactory.task {
            taskFactory.task {
                finishedTasksCount.mutate { $0 += 1 }
            }

            taskFactory.detached {
                finishedTasksCount.mutate { $0 += 1 }
            }

            finishedTasksCount.mutate { $0 += 1 }
        }
        await taskFactory.runUntilIdle()
        
        // then
        XCTAssertEqual(finishedTasksCount.value, 3)
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
