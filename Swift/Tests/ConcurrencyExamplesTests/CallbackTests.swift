import Dispatch
#if os(macOS) || os(tvOS) || os(iOS)
import Darwin
#endif
#if os(Linux)
import Glibc
#endif
import XCTest
import Future
@testable import ConcurrencyExamples


func rand(bound: UInt32) -> UInt32 {
#if os(Linux)
    return random() % bound
#else
    return arc4random() % bound
#endif
}


class ConcurrencyExamplesTests: XCTestCase {
    func delayedAsyncCall() -> AsyncService {
        return { call in
            let (_, callback): AsyncCall = call
            DispatchQueue(label: "delayedAsyncService").asyncAfter(deadline: .now() + .milliseconds(Int(rand(bound: 5000)))) {
                callback((), nil)
            }
        }
    }

    func testCallbacks() {
        let dg = DispatchGroup()
        dg.enter()
        callbackService(call: ((), { (_, _) in
            print("Got final response")
            dg.leave()
        }), downstreamServices: (0..<50).map{_ in delayedAsyncCall()})
        dg.wait()
    }

    func delayedFutureService() -> FutureService {
        return { _ in
                let p = Promise<Response>()
            DispatchQueue(label: "delayedAsyncService").asyncAfter(deadline: .now() + .milliseconds(Int(rand(bound: 5000)))) {
                p.succeed(result: ())
            }
            return p.futureResult
        }
    }

    func testFutures() {
        try! futureService(request: (), downstreamServices: (0..<50).map{_ in delayedFutureService()}).wait()
    }

    func testGreenThreads() {
        try! greenThreadService(request: (), downstreamServices: (0..<50).map{GreenThreadDelayService(id: $0)})
    }
}
