# Concurrency Models

This repository contains examples of how to code up a specific asynchronous task (defined below) under following concurrency models:

* [callback based, using Swift](Swift/Sources/ConcurrencyExamples/Callbacks.swift)
* [Future based, using Swift](Swift/Sources/ConcurrencyExamples/Futures.swift)
* [async/away, using Python](Python/async_await_syntax.py)
* green threads, using Go and Haskell
* actors, using Erlang

Each of the samples is runnable, see code comments in the samples above.

## Test case

Test case is to implement a 'racing proxy' which receives a request and responds asynchronously with response or error. The proxy doesn't implement any business logic. Instead, it hands over the request to number of 'downstream services', and returns the first successful result.

The API of the racing proxy itself is expressed idiomatically for each of the concurrency models chosen. For reference, the callback based API is:

```swift
typealias Callback = (Response?, Error?) -> ()
typealias AsyncCall = (Request, Callback)
typealias AsyncService = (AsyncCall) -> ()

func callbackService(call: AsyncCall, downstreamServices: [AsyncService]) -> ()
```

## Swift mock-ups

For concurrency models not currently expressible in Swift, we've attempted to mock them up below. The purpose of those mockups is to make comparison easier, and as such propose straw-man syntax. Complete design would require more analysis and care.

### Callbacks
[see here](Swift/Sources/ConcurrencyExamples/Callbacks.swift)

### Futures
[see here](https://github.pie.apple.com/gmilos/concurrency-examples/blob/master/Swift/Sources/ConcurrencyExamples/Futures.swift)

### async/await
```swift
func asyncAwaitService(request: Request, downstreamServices:[(Request) async throws -> Response]) async throws -> Response {
    guard downstreamServices.count > 0 else {
        throw ServiceError.noDownstreamService
    }

    let futures = downstreamServices.map { service in
        Future { try await service(request) }
    }

    if let response = await Future.firstSuccess(futures: futures).result() {
        return response
    }

    throw ServiceError.allDownstreamServicesFailed
}
```

Assumed Libraries:
```swift
import Dispatch


public protocol FutureProtocol {
    associatedtype Result

    func result() async throws -> Result
}

public func callWithCompletionHandler<T>(coroutine: () async throws -> T, completionHandler: @escaping (T?, Error?)) {
    (coroutine as (@escaping (T?, Error?) -> ()))(completionHandler)
}

public func asCoroutine<T>(_ completionHandler: @escaping (T?, Error?) -> ()) -> () async throws -> T {
    return completionHandler as () async throws -> T
}

// A possible implementation
public class Future<T> : FutureProtocol {
    public init(queue: DispatchQueue = .global(), coroutine: @escaping () async throws -> T) {
        self.queue = queue
        queue.async {
            callWithCompletionHandler(coroutine: coroutine, completionHandler: self.notifyCompleted)
        }
        sync = DispatchQueue(label: "swift.Future.sync", target: queue)
    }

    private enum State {
        case pending(callbacks: [(T?, Error?) -> ()])
        case success(T)
        case error(Error)
    }

    private let sync: DispatchQueue
    private var state: State = .pending(callbacks: [])

    private func callWhenResult(resultCallback: @escaping (T?, Error?) -> ()) {
        if let state = sync.sync {
            switch state {
            case pending(var callbacks):
                callbacks.append(resultCallback)
                self.state = .pending(callbacks)
                return nil
            default:
                return state
            }
        }
    }

    private func notifyCompleted(result: T?, error: Error?) {
        assert((result == nil && error != nil) || (error == nil && result != nil))
        let callbacks, args = sync.sync {
            guard case .pending(let callbacks) = self.state else {
                preconditionFailure("Can't complete twice")
            }
            if let result = result {
                self.state = .success(result)
                return callbacks, (result, nil)
            } else {
                self.state = .error(error!)
                return callbacks, (nil, error)
            }
        }
        for callback in callbacks {
            callback(args)
        }
    }


    public func result() async throws -> T {
        return try await asCoroutine(self.callWhenResult)
    }
}

public extension Future {
    public static func firstSuccessful<T>(futures: [Future<T>], queue: DispatchQueue = .global()) async -> T? {
        let sync = DispatchQueue(label: "org.swift.Future.firstSuccessful.sync", target: queue)
        // Guarded by `sync`
        let promise = Promise<T?>()
        for future in futures {
            _ = Future(queue: queue) {() async -> Void in
                if let result = try? await future.result() {
                    sync.sync {
                       if !promise.isFulfilled {
                           promise.fulfill(result: result)
                       }
                    }
                }
            }
        }
        _ = Future(queue: queue) {
            for future in futures {
                if try? await future.result() != nil {
                    return
                }
            }
            sync.sync {
                if !promise.isFulfilled {
                    promise.fulfill(result: nil)
                }
            }
        }
        return try! await promise.future.result()
    }
}
```

### green threads
```swift
//green threads placeholder
```

### actors
```swift
//actors placeholder
```

## Possible extensions

The simple 'racing proxy' doesn't capture all complexities of interacting with asynchronous APIs. In particular, we are looking at extending the above with:

* cancellation, to stop downstream services from doing potentially expensive work if the results are not going to be used
* back-pressure, if the proxy is receiving requests at a rate greater than what it can process (most likely because of downstream themselves becoming overloaded), how would it be able to both learn about such condition and notify the caller
* timeouts, limiting the allowed wait time for each of the downstream services
