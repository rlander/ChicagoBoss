%% Compose Chicago Boss's historical cut transform with the OTP 21 pmod
%% compatibility transform.  The order matters: boss_db uses cut syntax in
%% ordinary Erlang sources, and pmod_pt must see the rewritten forms.
-module(chicago_boss_pmod_pt).

-export([parse_transform/2, format_error/1]).

parse_transform(Forms, Options) ->
    Rewritten = cut:parse_transform(Forms, Options),
    pmod_pt:parse_transform(Rewritten, Options).

format_error(Reason) ->
    pmod_pt:format_error(Reason).
