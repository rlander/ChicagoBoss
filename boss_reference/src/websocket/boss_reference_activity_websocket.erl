-module(boss_reference_activity_websocket, [Req, SessionID]).
-compile(tuple_calls).

-behaviour(boss_service_handler).
-compile(export_all).

-record(state, {subscribers = []}).

init() ->
    {ok, #state{}}.

handle_join(_ServiceURL, Socket, State) ->
    case boss_reference_auth:current_user(SessionID) of
        {ok, User} ->
            send(Socket, [{event, "connected"}]),
            {noreply, add_socket(Socket, User:id(), State)};
        anonymous ->
            send(Socket, [{event, "unauthorized"}]),
            {noreply, State}
    end.

handle_incoming(_ServiceURL, Socket, Message, State) ->
    case decode_subscription(Message) of
        {ok, ProjectID} ->
            case subscribed_project(ProjectID) of
                true ->
                    send(Socket, [{event, "subscribed"},
                                  {project_id, ProjectID}]),
                    {noreply, set_project(Socket, ProjectID, State)};
                false ->
                    send(Socket, [{event, "unknown_project"}]),
                    {noreply, State}
            end;
        error ->
            {noreply, State}
    end.

handle_broadcast({Event, ProjectID, EntityID}, State)
  when Event =:= issue_created;
       Event =:= issue_updated;
       Event =:= issue_closed;
       Event =:= comment_added ->
    Payload = [{event, atom_to_list(Event)},
               {project_id, as_list(ProjectID)},
               {entity_id, as_list(EntityID)}],
    send_to_project(ProjectID, Payload, State),
    {noreply, State};
handle_broadcast(_Other, State) ->
    {noreply, State}.

handle_close(_Reason, _ServiceURL, Socket, State) ->
    {noreply, remove_socket(Socket, State)}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

decode_subscription(Message) when is_binary(Message) ->
    try jsx:decode(Message) of
        Data when is_list(Data) ->
            case proplists:get_value(<<"subscribe">>, Data,
                                     proplists:get_value("subscribe", Data)) of
                undefined -> error;
                ProjectID -> {ok, as_list(ProjectID)}
            end;
        _ -> error
    catch
        _:_ -> error
    end;
decode_subscription(Message) when is_list(Message) ->
    decode_subscription(list_to_binary(Message));
decode_subscription(_) ->
    error.

subscribed_project(ProjectID) ->
    boss_db:find(ProjectID) =/= undefined.

add_socket(Socket, UserID, #state{subscribers = Subscribers}) ->
    #state{subscribers = [{Socket, UserID, undefined} |
                          [Item || Item = {Other, _, _} <- Subscribers,
                                   Other =/= Socket]]}.

set_project(Socket, ProjectID, #state{subscribers = Subscribers}) ->
    Updated = lists:map(fun
        ({Socket, UserID, _}) -> {Socket, UserID, ProjectID};
        (Item) -> Item
    end, Subscribers),
    #state{subscribers = Updated}.

remove_socket(Socket, #state{subscribers = Subscribers}) ->
    #state{subscribers = [Item || Item = {Other, _, _} <- Subscribers,
                                  Other =/= Socket]}.

send_to_project(ProjectID, Payload, #state{subscribers = Subscribers}) ->
    lists:foreach(fun
        ({Socket, _UserID, ProjectID}) -> send(Socket, Payload);
        (_) -> ok
    end, Subscribers).

send(Socket, Payload) ->
    Socket ! {text, jsx:encode([{as_binary(Key), as_binary(Value)} ||
                                {Key, Value} <- Payload])},
    ok.

as_binary(Value) when is_binary(Value) -> Value;
as_binary(Value) when is_atom(Value) -> atom_to_binary(Value, utf8);
as_binary(Value) -> list_to_binary(as_list(Value)).

as_list(Value) when is_binary(Value) -> binary_to_list(Value);
as_list(Value) when is_list(Value) -> Value;
as_list(Value) when is_atom(Value) -> atom_to_list(Value);
as_list(Value) when is_integer(Value) -> integer_to_list(Value);
as_list(Value) -> lists:flatten(io_lib:format("~p", [Value])).
