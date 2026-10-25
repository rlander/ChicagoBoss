-module(legacy_compat_legacy_controller, [Req]).
-export([index/2, show/2, before_/1, after_/2, config/3]).

index('GET', []) ->
    {output, {index, Req}}.

show('GET', [Id]) ->
    {output, {show, Id, Req}}.

before_(_Action) ->
    ok.

after_(_Action, Result) ->
    {after_hook, Result}.

config(_Key, Default, _RequestContext) ->
    {configured, Default}.
