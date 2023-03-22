# Combine bindings for legacy systems

A bridge between Combine Publishers and Swift AsyncSequence 

## Overview

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
