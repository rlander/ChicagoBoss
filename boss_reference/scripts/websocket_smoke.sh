#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

rebar3 eunit >/dev/null
erl -noshell -pa _build/default/lib/*/ebin -pa _build/test/extras/test \
    -eval 'case boss_reference_websocket_smoke:run() of ok -> halt(0); Other -> io:format("~p~n", [Other]), halt(1) end.'
