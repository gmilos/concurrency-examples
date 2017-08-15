/* made up syntax:
  1. the `spawn` keyword to spawn an actor
     with it's `spawn linked` variant to spawn a linked actor (deaths propagate
     both ways)

  2. func foo(arg: Arg) actor<Message>

     creates an actor with argument `arg` of type `Arg` which can receive messages
     of type `Message`. Actors are always throwing. Errors get delivered to
     as messages
*/

typealias Request = ()
typealias Result = Int

enum ActorExit {
    case normal
    case error(Error)
}

protocol ActorMessage {
    init(exited: ActorExit)
}

class Actor<MessageType>: ActorMessage {
    ...
}

enum ProxyHubIn: ActorMessage {
    case workerResult(Result)
    case workerDied(ActorExit)

    init(exited: ActorExit) {
        self = .workerDied(exited)
    }
}

enum MainActorIn: ActorMessage {
    case proxyDone(Actor<>, Result)
    case workerDied(ActorExit)

    init(exited: ActorExit) {
        self = .workerDied(exited)
    }
}

struct AllDiedError: Error {}

// the worker
func workerMain(from: Actor<ProxyHubIn>, workerId: Int, request: ()) -> Void {
    // wait one second (emulate work)
    Actor.sleep(1)
    from.send(.workerResult(workerId))
}

// the proxy hub
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

func main() actor<MainActorIn> {
    Actor.processFlag(.trapExit, true)
    let req = ()
    _ = spawn linked proxy(from: self(), request: req)
    loop: while true {
        let msg = Actor.receive()
        switch msg {
            case .workerDied(.normal):
                continue // ignore, will get a .proxyDone message
            case .workerDied(let reason):
                print("Exiting because the proxy hub died: \(reason)")
                exit(1)
            case .proxyDone(_, let res):
                print("Got result: \(res)")
                exit(0)
        }
    }
}
