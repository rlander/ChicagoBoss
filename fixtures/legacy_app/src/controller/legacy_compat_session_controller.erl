-module(legacy_compat_session_controller, [Req, SessionID]).
-export([index/2]).

index('GET', []) ->
    {output, {session, Req, SessionID}}.
