import Dispatch

/**
Run with:

```
cd Swift/
swift test --filter testCallbacks
```
*/
typealias Callback = (Response?, Error?) -> ()
typealias AsyncCall = (Request, Callback)
typealias AsyncService = (AsyncCall) -> ()

func callbackService(call: AsyncCall, downstreamServices: [AsyncService]) {
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



