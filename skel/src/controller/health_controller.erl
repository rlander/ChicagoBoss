-module({{name}}_health_controller, [Req]).
-export([index/2]).

index('GET', []) ->
    {output, "ok"};
index('HEAD', []) ->
    {output, "ok"}.
