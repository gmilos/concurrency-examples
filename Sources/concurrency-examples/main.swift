import Dispatch
#if os(macOS) || os(tvOS) || os(iOS)
import Darwin
#endif
#if os(Linux)
import Glibc
#endif

// Typealias setup
typealias Request = ()
typealias Response = ()

typealias Callback = (Response) -> ()
typealias AsyncCall = (Request, Callback)
typealias AsyncService = (AsyncCall) -> ()


// Implementation
func service(mainHandler: AsyncCall, downstreamServices: [AsyncService]) {
    let (req, callback): AsyncCall = mainHandler

    // TODO: error if empty service list

    // protected by q below
    var isFirst = true
    let isFirstQ = DispatchQueue(label: "isFirst")
    for downstreamService in downstreamServices {
        print("Calling a downstream service")
        downstreamService((req, { resp in
            let isFirstResponse: Bool = isFirstQ.sync {
                let localIsFirst = isFirst
                isFirst = false
                return localIsFirst
            }
            if isFirstResponse {
                callback(resp)
            }
        }))
    }
}




// Runner
func rand(bound: UInt32) -> UInt32 {
#if os(Linux)
    return random() % bound
#else
    return arc4random() % bound
#endif
}

func delayedAsyncCall() -> AsyncService {
    return { call in
        let (req, callback): AsyncCall = call
        DispatchQueue(label: "delayedAsyncService").asyncAfter(deadline: .now() + .milliseconds(Int(rand(bound: 5000)))) {
            callback(())
        }
    }
}

let dg = DispatchGroup()
dg.enter()
service(mainHandler: ((), { rsp in
    print("Got final response")
    dg.leave()
}), downstreamServices: (0..<50).map{_ in delayedAsyncCall()})
dg.wait()
