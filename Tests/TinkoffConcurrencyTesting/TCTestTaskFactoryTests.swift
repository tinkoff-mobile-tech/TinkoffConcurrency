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

    func test_taskStarted_whenTaskCreated() async throws {
        // given
        let isTaskStarted = UncheckedSendable(false)
        
        // when
        let task = TCTestTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.task {
                isTaskStarted.mutate { $0 = true }
                
                XCTAssertEqual(TCTestTaskFactoryTests.testValue, 999)
            }
        }
        _ = await task.value
        
        // then
        XCTAssertTrue(isTaskStarted.value)
    }

    func test_taskStarted_whenDetachedTaskCreated() async throws {
        // given
        let isTaskStarted = UncheckedSendable(false)
                
        // when
        let task = TCTestTaskFactoryTests.$testValue.withValue(999) {
            taskFactory.detached {
                isTaskStarted.mutate { $0 = true }
                
                XCTAssertEqual(TCTestTaskFactoryTests.testValue, 42)
            }
        }
        _ = await task.value
        
        // then
        XCTAssertTrue(isTaskStarted.value)
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
