import XCTest

import TinkoffConcurrencyTesting

final class TCTestTaskFactoryTests: XCTestCase {

    // MARK: - Dependencies

    private var taskFactory: TCTestTaskFactory!

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
        let task = taskFactory.task {
            isTaskStarted.mutate { $0 = true }
        }
        _ = try await task.value
        
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
        }
        try await taskFactory.runUntilIdle()
        
        // then
        XCTAssertEqual(finishedTasksCount.value, tasksCount)
    }
    
    func test_runUntilIdle_whenCreatedInternalTaskInRunningAsynchronousWork() async throws {
        // given
        let tasksCount = 2
        let finishedTasksCount = UncheckedSendable(0)

        // when
        taskFactory.task {
            self.taskFactory.task {
                finishedTasksCount.mutate { $0 += 1 }
            }
            finishedTasksCount.mutate { $0 += 1 }
        }
        try await taskFactory.runUntilIdle()
        
        // then
        XCTAssertEqual(finishedTasksCount.value, tasksCount)
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
