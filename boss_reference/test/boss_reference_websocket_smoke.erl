-module(boss_reference_websocket_smoke).

-export([run/0]).

run() ->
    {ok, Socket} = gen_tcp:connect("127.0.0.1", 8001,
                                  [binary, {active, false}], 5000),
    Key = base64:encode(crypto:strong_rand_bytes(16)),
    Request = [
        "GET /websocket/activity HTTP/1.1\r\n",
        "Host: 127.0.0.1:8001\r\n",
        "Upgrade: websocket\r\n",
        "Connection: Upgrade\r\n",
        "Sec-WebSocket-Version: 13\r\n",
        "Sec-WebSocket-Key: ", Key, "\r\n\r\n"
    ],
    ok = gen_tcp:send(Socket, Request),
    {ok, Response} = gen_tcp:recv(Socket, 0, 5000),
    true = binary:match(Response, <<"101 Switching Protocols">>) =/= nomatch,
    ok = gen_tcp:close(Socket),
    ok.
