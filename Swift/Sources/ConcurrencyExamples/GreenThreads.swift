import Foundation // Really this would be "ServerFoundation"

fileprivate func go(coroutine: @escaping () -> ()) {
    guard #available(macOS 10.12, *) else {
        fatalError()
    }
    Thread.detachNewThread(coroutine)
}

fileprivate class UnbufferedChannel<T> {
    private let condition = NSCondition()
    private var value: T?

    func send(_ value: T) {
        condition.lock()
        defer { condition.unlock() }
        while self.value != nil {
            condition.wait()
        }
        self.value = value
        condition.signal()
        condition.unlock()
    }

    func receive() -> T {
        condition.lock()
        defer { condition.unlock() }
        while self.value == nil {
            condition.wait()
        }
        let result = self.value!
        self.value = nil
        condition.signal()
        return result
    }
}

struct GreenThreadDelayService {
    private let id: Int
    private let delay: TimeInterval

    init(id: Int) {
        self.id = id
        self.delay = Double("\(id)".hashValue % 1000) / 1000.0
    }

    func service(request: Request) throws -> Response {
        if true { throw ServiceError.noDownstreamService }
        Thread.sleep(forTimeInterval: delay)
        return Response()
    }
}

func greenThreadService(request: Request, downstreamServices: [GreenThreadDelayService]) throws ->
Response {
    if downstreamServices.isEmpty {
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
