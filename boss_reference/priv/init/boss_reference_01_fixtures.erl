-module(boss_reference_01_fixtures).

-export([init/0, stop/1]).

init() ->
    case boss_reference_fixtures:seed() of
        {atomic, Result} -> {ok, Result};
        Result -> {ok, Result}
    end.

stop(_State) ->
    ok.
