# Combine bindings for legacy systems

A bridge between Combine Publishers and Swift Concurrency 

## Overview

### asyncValues

TinkoffConcurrency provides a [Publisher.values](https://developer.apple.com/documentation/combine/publisher/values-v7nz)
alternative which allows you to use the Swift `async`-`await` syntax to receive the publisher's elements.

It follows Apple's [Publisher.values](https://developer.apple.com/documentation/combine/publisher/values-v7nz) contract, but is
available on earlier OS versions.

The following example shows how to use the `asyncValues` property to receive elements asynchronously.
The example adapts a code snippet from the [filter(_:)](https://developer.apple.com/documentation/combine/publisher/filter(_:)) operator's documentation,
which filters a sequence to only emit even integers. This example replaces the
[Subscribers.Sink](https://developer.apple.com/documentation/combine/subscribers/sink)
subscriber with a `for`-`await`-`in` loop that iterates over the ``TCAsyncPublisher``
provided by the `asyncValues` property.

```swift
    let numbers: [Int] = [1, 2, 3, 4, 5]
    let filtered = numbers.publisher
        .filter { $0 % 2 == 0 }

    for await number in filtered.asyncValues
    {
        print("\(number)", terminator: " ")
    }
```

### Async Channel

In addition to `asyncValues`, which is Combine → Swift Concurrency bridge, Tinkoff Concurrency provides another
one that allows sending data from Swift Concurrency to Combine respecting Combine's backpressure. We call it ``TCAsyncChannel``.

Basically, this contract is borrowed from Apple Async Algorithms [AsyncChannel](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md)
behavior. Consider the following example:

```swift
    let subject = PassthroughSubject<String, Error>()

    Task {
        while let value = getValue() {
            subject.send(value)
        }

        subject.send(completion: .finished)
    }

    for await value in subject.asyncValues {
        await useValue(value)
    }
```

If `getValue()` is executed fast enough, we can lose some values, because `PassthroughSubject` would drop them until
subscription is ready to receive. Fortunately, in async context, we can use Combine's backpressure mechanism to synchronize
reader and writer. In the next example, no values would be lost, because ``TCAsyncChannel/send(_:)`` will wait until
there's at least one subscriber, and all subscribers are ready to receive a value.

```swift
    let channel = TCAsyncChannel<String, Error>()

    Task {
        while let value = getValue() {
            try await channel.send(value)
        }

        try channel.send(completion: .finished)
    }

    for await value in channel.asyncValues {
        await useValue(value)
    }
```

This way, ``TCAsyncChannel`` can be used as a synchronization primitive like Golang `chan` or 
[AsyncChannel](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md) 

Bear in mind, however, that there still could be race conditions. In example below, some initial values could be skipped by one of the readers,
depending on when subscription is scheduled. But, when both subscriptions are estabilished, next value could be submitted only when previous value
is consumed by both of the readers.

```swift
    let channel = TCAsyncChannel<String, Error>()

    Task {
        while let value = getValue() {
            try await channel.send(value)
        }

        try channel.send(completion: .finished)
    }

    Task {
        for await value in channel.asyncValues {
            await doSomething(with: value)
        }
    }

    Task {
        for await value in channel.asyncValues {
            await doSomethingElse(with: value)
        }
    }
```
