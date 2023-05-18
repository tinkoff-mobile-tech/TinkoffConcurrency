# Continuations with task cancellation support

Wrapping an async operation that can be cancelled into a throwing async method that can respect Task
cancellation.

## Overview

With Swift Concurrency that came with Swift 5.5, we have an amazing tool that makes concurrent code
look just like a conventional one, when logic is being read from top to bottom, eliminating so-called
"callback hell". As a bridge between callback-based world and async methods, one can use
[withCheckedContinuation](https://developer.apple.com/documentation/swift/withcheckedcontinuation(function:_:)) /
[withCheckedThrowingContinuation](https://developer.apple.com/documentation/swift/withcheckedthrowingcontinuation(function:_:))
to wrap an existing callback-based method. Say, we have some asynchronous operation like

```swift
func someAsyncOperation(completion: @escaping (Result<String, Error>) -> Void)
```

Wrapping it to async method is easy:
```swift
func someAsyncOperation() async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        someAsyncOperation(completion: continuation.resume(with:))
    }
}
```

but, we have a problem wrapping operations that can be cancelled. Given a method like

```swift
func someAsyncCancellableOperation(completion: @escaping (Result<String, Error>) -> Void) -> CancellationToken
```

With new ``withCheckedThrowingCancellableContinuation(function:_:)`` we can wrap it like so: 
```swift
func someAsyncCancellableOperation() async throws -> String {
    try await withCheckedThrowingCancellableContinuation { completion in
        let token = someAsyncCancellableOperation(completion: completion)

        return TCCancellableClosure {
            // perform whatever cancel actions needed
            cancelOperation(token)
        }
    }
}
```
or, even simpler, if cancellable token has
```swift
func cancel()
```
wrapping becomes trivial:
```swift
extension CancellationToken: TCCancellable {}

func someAsyncCancellableOperation() async throws -> String {
    try await withCheckedThrowingCancellableContinuation { completion in
        someAsyncCancellableOperation(completion: completion)
    }
}
```

``withCheckedThrowingCancellableContinuation(function:_:)`` ensures that continuation will be resumed only once, either
by resolving a completion closure, or when task is cancelled. In later case, it throws 
[CancellationError](https://developer.apple.com/documentation/swift/cancellationerror). That's why only throwing variant
is available, in contrast to [withCheckedContinuation](https://developer.apple.com/documentation/swift/withcheckedcontinuation(function:_:)) /
 [withCheckedThrowingContinuation](https://developer.apple.com/documentation/swift/withcheckedthrowingcontinuation(function:_:))


## Topics

### Functions

- ``withCheckedThrowingCancellableContinuation(function:_:)``
