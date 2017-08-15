# Concurrency Models

This repository contains examples of how to code up a specific asynchronous task (defined below) under following concurrency models:

* [callback based, using Swift](Swift/Sources/ConcurrencyExamples/Callbacks.swift)
* [Future based, using Swift](Swift/Sources/ConcurrencyExamples/Futures.swift)
* [async/away, using Python](Python/async_await_syntax.py)
* green threads, using [Go](Go/goroutines.go) and [Haskell](Haskell+STM/proxy_racer.hs)
* [actors, using Erlang](Erlang/racer_proxy.erl)

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

Support library code needed to implement the below is [here](Swift/Sources/AsyncAwaitLibs.swift).

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


### green threads

Full mocked up Swift version [here](Swift/Sources/ConcurrencyExamples/GreenThreads.swift) (works, but assumes `Thread` is cheap).

```swift
func greenThreadService(request: Request, downstreamServices: [GreenThreadDelayService]) throws ->
Response {
    if downstreamServices.isEmpty {
        throw ServiceError.noDownstreamService
    }
    let results = UnbufferedChannel<(Response?, Error?)>()
    for s in downstreamServices {
        go {
            do {
                results.send((try s.service(request: request), nil))
            } catch {
                results.send((nil, error))
            }
        }
    }
    for _ in downstreamServices {
        if case let (.some(result), .none) = results.receive() {
            return result
        }
    }
    throw ServiceError.allDownstreamServicesFailed
}
```

### actors

Please find the full mocked up Swift version
[here](MockSwift-Erlang-Actors/racer_proxy.swift) and the actually working Erlang implementation [here](Erlang/racer_proxy.erl).

```swift
func proxy(from: Actor<MainActorIn>, request: Request) actor<ProxyHubIn> -> Void {
    // we want to get notified when the workers die, even though we'll spawn with
    // link
    Actor.processFlag(.trapExit, true)
    let numWorkers = 10000
    let me: actor<ProxyHubIn> = Actor.self
    for wid in 1...numWorkers {
        _ = spawn linked workerMain(from: me, workerId: wid, request: ())
    }
    var deadWorkers = 0
    while true {
        if numWorkers == deadWorkers {
            throw AllDiedError()
        }
        switch Actor.receive() {
            case .workerDied(.normal):
                // worker went down normally (we should have received a result)
                continue
            case .workerDied(.error(_)):
                // worker died, need to account for that
                deadWorkers += 1
                continue
            case .workerResult(let res):
                // got a worker result, communicate back
                from.send(.proxyDone(Actor.self, res))
                break
        }
    }
}
```

## Possible extensions

The simple 'racing proxy' doesn't capture all complexities of interacting with asynchronous APIs. In particular, we are looking at extending the above with:

* cancellation, to stop downstream services from doing potentially expensive work if the results are not going to be used
* back-pressure, if the proxy is receiving requests at a rate greater than what it can process (most likely because of downstream themselves becoming overloaded), how would it be able to both learn about such condition and notify the caller
* timeouts, limiting the allowed wait time for each of the downstream services
