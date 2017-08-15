typealias WorkerId = Int
typealias Request = ()
typealias Response = WorkerId

-- | the proxy worker itself which does the work
func proxyWorker(_ args: (WorkerId, Request)) throws -> Response {
  let workerId: Int = args.0
  let req: Request = args.1
  let delay = (1 + (workerId / 10)) * 1000 * 1000
  GreenThread.sleep(delay)  -- wait 1 + |_ workerId/10 _| seconds, emulates doing work
  return workerId
}

-- | turns a proxy worker (returning its result) into one that writes it to a
-- TMVar (think a thread-safe box). It also accounts for the number of results
-- seen so far.
func channelise<Req, Res>(state: TransactionalVariable<(Int, Either<Err, Res>)>,
                          worker: (Req) throws -> Res) -> ((Req) -> Void) {
  return { (req: Req) -> Void in
    let res
    do {
        /* run the function that processes the request */
        res = .right(try worker(request))
    } catch e {
        res = .left(e)
    }
    atomically {
      let v = state.read() /* inspect the currently best result */
      switch v {
          case (let num, .right(let val):
              /* already successful, leave current result */
              state.write((num+1, val))
          case (let num, .left(_)):
              /* unsuccessful so far, write this thread's value */
              state.write((num+1, result))
      }
    }
  }
}

enum Either<L, R> {
    case left(L)
    case right(R)
}

func main() {
  let cmdArgs = CommandLine.arguments
  let numWorkers: Int
  switch cmdArgs.flatMap({ Int($0) }).first {
      case .some(let num):
          numWorkers = num
      case .none:
          numWorkers = 10000
  }
  var state = atomically {
      TransactionalVariable((0, Left "only errors"))
  }
  for wid in 1...numWorkers {
      let t = GreenThread(channelise(state: state, worker: proxyWorker),
                          (wid, ())
      t.start()
  }
  do {
      let value = try atomically { (tx: Transaction) throws -> Int in
          switch state.read() { /* inspect the current best result */
              case (_, .right(let res)):
                return res
              case (let num, .left(let res)):
                if num == numWorkers {
                    throw AllFailed(res):
                } else {
                    tx.retry() /* retries the transaction but only if it makes sense
                                  (like a condition variable) */
                }
          }
      }
      print("Success: \(value)")
  } catch e {
      print("all failed: \(e)")
  }
}
