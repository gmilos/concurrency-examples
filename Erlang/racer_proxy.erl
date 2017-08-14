%% to run the program:
%%   erl -compile racer_proxy.erl && erl -p -run racer_proxy start -run init stop -noshell
-module(racer_proxy).

-export([main/1, proxy/2, start/0]).

start() -> main(1).

%% the worker
worker_main(From, Arg, {}) ->
    % wait one second (emulate work)
    timer:sleep(timer:seconds(1)),
    % send the answer back
    From ! { worker_result, Arg }.

%% the proxy hub
loop(_, NumWorkers, DeadWorkers) when NumWorkers == DeadWorkers ->
    exit(all_died);
loop(From, NumWorkers, DeadWorkers) ->
    receive
        { 'EXIT', _, normal } ->
            % worker went down normally (we should have received a result)
            loop(From, NumWorkers, DeadWorkers);
        { 'EXIT', _, _ } ->
            % worker died, need to account for that
            loop(From, NumWorkers, DeadWorkers + 1);
        { worker_result, Res } ->
            % got a worker result, communicate back
            From ! { proxy_done, self(), Res },
            exit(ok);
        _ -> exit(unexpected)
    end.

proxy(From, Request) ->
    % we want to get notified when the workers die, even though we'll spawn with
    % link
    process_flag(trap_exit, true),
    NumWorkers = 10000,
    Me = self(),
    lists:map(fun(WorkerId) ->
                      spawn_link(fun() -> worker_main(Me, WorkerId, Request) end)
              end,
              lists:seq(1, NumWorkers)),
    loop(From, NumWorkers, 0).

%% the main program
main(_) ->
    process_flag(trap_exit, true),
    Req = {},
    _ = spawn_link(racer_proxy, proxy, [self(), Req]),
    receive
        {'EXIT', Pid, Reason} ->
            io:format("Exiting because ~p died: (~p) ~n", [Pid, Reason]);
        {proxy_done, _, Res} ->
            io:format("Got result: ~p~n", [Res]);
        Unexpected ->
            io:format("ERROR: unexpected stuff: ~p~n", [Unexpected]),
            exit(error)
    end.
