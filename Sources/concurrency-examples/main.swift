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

typealias Callback = (Response?, Error?) -> ()
typealias AsyncCall = (Request, Callback)
typealias AsyncService = (AsyncCall) -> ()

enum ServiceError : Error {
    case noDowntstreamService
    case allDowntstreamServicesFailed
}


// Implementation
func service(call: AsyncCall, downstreamServices: [AsyncService]) {
    let (req, callback): AsyncCall = call

    guard downstreamServices.count > 0 else {
        callback(nil, ServiceError.noDowntstreamService)
        return
    }

    // protected by q below
    var _first = true
    let _firstQ = DispatchQueue(label: "first")
    func first() -> Bool {
        return _firstQ.sync {
            let __first = _first
            _first = false
            return __first
        }
    }

    let serviceCounter = DispatchGroup()
    for downstreamService in downstreamServices {
        print("Calling a downstream service")
        serviceCounter.enter()
        downstreamService((req, { (response, error) in
            guard let response = response else {
                serviceCounter.leave()
                return
            }
            if first() {
                callback(response, nil)
            }
            serviceCounter.leave()
        }))
        if first() {
            callback(nil, ServiceError.allDowntstreamServicesFailed)
        }
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
            callback((), nil)
        }
    }
}

let dg = DispatchGroup()
dg.enter()
service(call: ((), { (_, _) in
    print("Got final response")
    dg.leave()
}), downstreamServices: (0..<50).map{_ in delayedAsyncCall()})
dg.wait()
