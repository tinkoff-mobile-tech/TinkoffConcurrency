# Changelog

## [Unreleased]

**Add**

- **Podspec**

  - `static_framework` set to true

## [2.0.0] - 2023-05-29Z

**Add**

- **TinkoffConcurrency**
  
  - `TCTaskFactory` a tool to abstract task creation

- **TinkoffConcurrencyTesting**
  
  - `TCTestTaskFactory` a tool to collect created tasks and wait for them to complete. To be used in unit tests.

## [1.2.0] - 2023-04-05Z

**Add**

- `TCAsyncChannel` a subject-like object which sends data respecting Combine's backpressure.

### [1.1.0] - 2023-03-24Z

**Add**

- `TCAsyncPublisher`
- `TCAsyncThrowingPublisher`
- `asyncValues` extensions for Publisher

### 1.0.0
Release date: **02.03.2023**

**Add**

- `TCCancellable` a general cancellable interface
- `TCCancellableClosure` concrete implementation which invokes closure on cancel
- `TCCancellablesStorage` a storage of cancellables
- `withCheckedThrowingCancellableContinuation`
