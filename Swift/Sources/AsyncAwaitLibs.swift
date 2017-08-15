import Dispatch


public protocol FutureProtocol {
    associatedtype Result

    func result() async throws -> Result
}

public func callWithCompletionHandler<T>(coroutine: () async throws -> T, completionHandler: @escaping (T?, Error?) -> ()) {
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
            case .pending(var callbacks):
                callbacks.append(resultCallback)
                self.state = .pending(callbacks)
                return nil
            default:
                return state
            }
        }
        switch state {
        case .success(let result):
            resultCallback(result, nil)
        case .error(let error):
            resultCallback(nil, error)
        default:
            return
        }
    }

    private func notifyCompleted(result: T?, error: Error?) {
        assert((result == nil && error != nil) || (error == nil && result != nil))
        let callbacks = sync.sync {
            guard case .pending(let callbacks) = self.state else {
                preconditionFailure("Can't complete twice")
            }
            if let result = result {
                self.state = .success(result)
                return callbacks
            } else {
                self.state = .error(error!)
                return callbacks
            }
        }
        for callback in callbacks {
            callback(result, error)
        }
    }


    public func result() async throws -> T {
        return try await asCoroutine(self.callWhenResult)()
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

