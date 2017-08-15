-- run:
--   runhaskell proxy_racer.hs
--
-- to have it compiled and use the threaded runtime:
--   ghc -- -rtsopts -threaded --make proxy_racer.hs && ./proxy_racer +RTS -threaded -N
module Main where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (atomically, retry, readTMVar, newTMVar, putTMVar, takeTMVar, TMVar)
import Data.Maybe (mapMaybe)
import System.Environment (getArgs)

type WorkerId = Int
type Request = ()
type Response = WorkerId
type Error = String

-- | the proxy worker itself which does the work
proxyWorker :: WorkerId -> Request -> IO (Either Error Response)
proxyWorker workerId _ = do
  let delay = (1 + (workerId `quot` 10)) * 1000 * 1000
  threadDelay delay  -- wait 1 + |_ workerId/10 _| seconds, emulates doing work
  return $ Right workerId

-- | turns a proxy worker (returning its result) into one that writes it to a
-- TMVar (think a thread-safe box). It also accounts for the number of results
-- seen so far.
channelise :: TMVar (Int, Either err res) -> (req -> IO (Either err res)) -> (req -> IO ())
channelise var f = \request -> do
  -- run the function that processes the request
  result <- f request
  atomically $
    do v <- takeTMVar var                          -- inspect the currently best result
       putTMVar var (case v of
                       (num, val@(Right _)) -> (num+1, val) -- already successful --> leave `val`
                       (num, Left _) -> (num+1, result)     -- unsuccessful --> put this thread's value
                    )

main :: IO ()
main = do
  cmdArgs <- getArgs
  let numWorkers = case mapMaybe readMaybe cmdArgs of
                     (num:_) -> num
                     _ -> 10000
  var <- atomically $ newTMVar (0, Left "only errors")
  let workerTasks = map (channelise var (uncurry proxyWorker))
                        (zip [1..numWorkers] (repeat ()))
  mapM_ forkIO workerTasks
  value <- atomically $
             do v <- readTMVar var                      -- read the current best result
                case v of
                  (_, Right res) -> return $ Right res  -- it's successful --> use it immediately
                  (num, res) -> if num == numWorkers
                                   then return res      -- it's unsuccessful but all workers are done
                                   else retry           -- it's unsuccessful and there's still outstanding workers
  print value

readMaybe :: Read a => String -> Maybe a
readMaybe s = case reads s of
                  [(val, "")] -> Just val
                  _           -> Nothing
