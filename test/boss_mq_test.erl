%%-------------------------------------------------------------------
%% @author
%%     ChicagoBoss Team and contributors, see AUTHORS file in root directory
%% @end
%% @copyright
%%     This file is part of ChicagoBoss project.
%%     See AUTHORS file in root directory
%%     for license information, see LICENSE file in root directory
%% @end
%% @doc
%%-------------------------------------------------------------------

-module(boss_mq_test).
-include("std.hrl").


convert_to_ms_test() ->
    ?assertEqual(infinity, boss_mq:convert_to_ms(infinity)),
    ?assertEqual(1000, boss_mq:convert_to_ms(1)).

tinymq_push_poll_test_() ->
    {setup,
        fun start_tinymq/0,
        fun stop_tinymq/1,
        fun(_Context) ->
            fun() ->
                Channel = "boss_mq_eunit_" ++ integer_to_list(erlang:unique_integer([positive])),
                ?assertMatch({ok, _}, boss_mq:push(Channel, "Test Message")),
                ?assertMatch({ok, _, ["Test Message"]}, boss_mq:poll(Channel, last))
            end
        end}.

start_tinymq() ->
    case global:whereis_name(boss_mq_sup) of
        undefined ->
            {ok, Pid} = boss_mq:start(),
            unlink(Pid),
            {started, Pid};
        Pid ->
            {already_started, Pid}
    end.

stop_tinymq({started, Pid}) ->
    exit(Pid, shutdown),
    application:stop(tinymq),
    ok;
stop_tinymq({already_started, _Pid}) ->
    ok.


% spec_test_() ->
%     gen([
%          fun prop_pull_recieve/0,
%          fun prop_pull_recieve_timeout/0,
%          fun prop_pull_recieve_error/0,
%          {stop, 0},
%          {convert_to_ms, 1},
%          {make_queue_options, 0}
%         ], boss_mq).

-type date()     :: {1970..2030, 1..12, 1..31}.
-type time()     :: {0..23, 0..59, 0..60}.
-type datetime() :: {date(), time()}.
prop_pull_recieve() ->
    ?FORALL({Msg, PullTime},
            {{refrence, datetime(), jsx:json_text()},
             datetime()},
             begin
                 self() ! Msg,
                 {ok, NewTimeStamp, Messages}       = boss_mq:pull_recieve(100, {ok, PullTime}),
                 {refrence, NewTimeStamp, Messages} =:= Msg

             end).
prop_pull_recieve_timeout() ->
    ?FORALL({ Pulltime},
             {datetime()},
             begin
                 {ok, Pulltime, []}  =:= boss_mq:pull_recieve(1, {ok, Pulltime})
             end).

prop_pull_recieve_error() ->
    ?FORALL(
       Error,
       {error, string()},

        begin
            Error  =:= boss_mq:pull_recieve(1, Error)
        end).
