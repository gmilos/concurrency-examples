import Future

/**
Run with:

```
cd Swift/
swift test --filter testFutures
```
*/
typealias FutureService = (Request) -> Future<Response>

func futureService(request: Request, downstreamServices: [FutureService]) -> Future<Response> {
    guard downstreamServices.count > 0 else {
        let p = Promise<Response>()
        p.fail(error: ServiceError.noDowntstreamService)
        return p.futureResult
    }

    let futures = downstreamServices.map { $0(request) }
    return Future.firstSuccess(futures: futures).thenIfError { (Error) throws -> Response in
        throw ServiceError.allDowntstreamServicesFailed
    }
}

