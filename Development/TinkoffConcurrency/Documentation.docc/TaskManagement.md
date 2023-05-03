# Task Management

Tools to manage task creation and usage

## Overview

### A problem

While task creation and awaiting is easy, uncontrolled task creation can make testing much harder and slower. Consider
the following example

```swift
struct MyEntity {
    let someDependency: ISomeDependency

    func doSomething() {
        Task {
            await someDependency.perform() 
        }
    }
}
```

If we want to test whether `someDependency.perform()` is invoked, we might write a following test

```swift
func testMyEntity_someDependency_perform() {
    // given
    let someDependency = SomeDependencyMock()

    let myEntity = MyEntity(someDependency: someDependency)

    // when
    myEntity.doSomething()

    // then
    XCTAssertTrue(someDependency.invokedPerform)
}
```

But, this test would fail, because `someDependency.perform()` is scheduled to be run on another thread, 
and we must wait for task to complete. With current implementation, the only way to do that is to wait for
some time to ensure that all scheduled tasks have finished. This way, we waste time just to wait uncontrolled
dependency to perform.

### Solution

Let's rewrite code above with one small change:

```swift
struct MyEntity {
    let taskFactory: ITCTaskFactory
    let someDependency: ISomeDependency

    func doSomething() {
        taskFactory.task {
            await someDependency.perform() 
        }
    }
}
```

Then, a test would change to

```swift
func testMyEntity_someDependency_perform() async {
    // given
    let taskFactory = TCTestTaskFactory()
    let someDependency = SomeDependencyMock()

    let myEntity = MyEntity(taskFactory: taskFactory, someDependency: someDependency)

    // when
    myEntity.doSomething()

    await taskFactory.runUntilIdle()

    // then
    XCTAssertTrue(someDependency.invokedPerform)
}
```

With this change, test will still run instantly, but internal task is guaranteed to be waited.

## Topics

### Task Factory

- ``ITCTaskFactory`` a protocol for task creation abstraction

- ``TCTaskFactory`` task creation abstraction entity to be used in production code

