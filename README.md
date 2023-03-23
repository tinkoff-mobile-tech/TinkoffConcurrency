# TinkoffConcurrency

## TL;DR

```swift
// Make URLSessionDataTask conform to TCCancellable
extension URLSessionDataTask: TCCancellable {}

func download(from url: URL) async throws -> Data {
    await withCheckedThrowingCancellableContinuation{ completion in
        let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, _, error in
            if let data = data {
                completion(.success(data))
            } else if let error = error {
                completion(.failure(error))
            } else {
                completion(.failure(Errors.unknownError))
            }
        }

        task.resume()

        return task
    }
}
```

```swift
let numbers: [Int] = [1, 2, 3, 4, 5]
let filtered = numbers.publisher
    .filter { $0 % 2 == 0 }

// Available from iOS 13
for await number in filtered.asyncValues {
    print("\(number)", terminator: " ")
}
```

## Requirements

TinkoffConcurrency requires Swift 5.5 and higher, with support of Swift Concurrency. This way, all Xcode versions starting from 13.0 would work.
It's advisable to use Xcode at least 13.2.1 or higher, as it provides backward compatibility with iOS 13.0 and higher.

## Installation

TinkoffConcurrency is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'TinkoffConcurrency'
```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first. Example app is a small demo that
illustrates behavior of `withCheckedThrowingCancellableContinuation` for both cancellable and non-cancellable tasks, and compares that
to vanilla `withCheckedThrowingContinuation` behavior.

Example application needs iOS 15.0 to run, as it uses new SwiftUI features. It does NOT imply any restrictions of using TinkoffConcurrency
library on older iOS versions.

## Authors

Timur Khamidov, t.khamidov@tinkoff.ru
Aleksandr Darovskikh, ext.adarovskikh@tinkoff.ru

## License

TinkoffConcurrency is available under the Apache 2.0 license. See the LICENSE file for more info.

## Attributions

Thank you [Point-free](https://github.com/pointfreeco/combine-schedulers) for test Combine scheduler
