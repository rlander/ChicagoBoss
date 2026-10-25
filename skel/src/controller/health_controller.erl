-module({{name}}_health_controller).
-export([new/1, index/3]).

%% The historical controller adapter expects a pmod-style new/1 and /2
%% action API. A {Module, State} tuple emulates the parameterized-module
%% instance that the adapter's tuple-call transform expects, while avoiding
%% OTP 21's removed parameterized-module syntax.
new(_Req) ->
    {?MODULE, undefined}.

index('GET', [], _Instance) ->
    {output, "ok"};
index('HEAD', [], _Instance) ->
    {output, "ok"}.
