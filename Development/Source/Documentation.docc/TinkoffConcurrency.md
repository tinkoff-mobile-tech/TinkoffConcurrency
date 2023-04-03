# ``TinkoffConcurrency``

TinkoffConcurrency is a set of tools that fill some gaps when integrating Swift Concurrency to your project.

## Overview

When integrating Swift Concurrency to an existing project, there are a couple of issues that needs to be solved.
Some of these issues are

- <doc:CancellableContinuation>
- <doc:CombineBindings>

This library provides ``withCheckedThrowingCancellableContinuation(function:_:)`` method to wrap existing
callback-based code as one would do using 
 [withCheckedThrowingContinuation](https://developer.apple.com/documentation/swift/withcheckedthrowingcontinuation(function:_:)),
and ``TinkoffConcurrency/Combine/Publisher/asyncValues-5znmm`` extension method for Combine [Publisher](https://developer.apple.com/documentation/combine/publisher), which reflects
Apple's [values](https://developer.apple.com/documentation/swift/result/publisher-swift.struct/values-7yerq) behavior, but is available
on older systems.

Supplementary tools like ``TCCancellablesStorage`` could also be useful, if a group of cancellable operations needs to be treated like
a single cancellable
