-module(boss_reference_model_test).

-compile(tuple_calls).
-include_lib("eunit/include/eunit.hrl").

model_and_policy_test_() ->
    {setup, fun setup/0, fun cleanup/1,
     [fun issue_validation_case/0,
      fun association_case/0,
      fun authentication_case/0,
      fun test_support_case/0,
      fun bounded_invariant_case/0,
      fun websocket_malformed_message_case/0,
      fun websocket_broadcast_case/0]}.

setup() ->
    case global:whereis_name(boss_news) of
        undefined ->
            {ok, _} = boss_news:start();
        _ -> ok
    end,
    case global:whereis_name(boss_db_mock) of
        undefined ->
            {ok, _} = boss_db:start([{adapter, mock}]);
        _ -> ok
    end,
    boss_db:push(),
    {atomic, _} = boss_reference_fixtures:seed(),
    ok.

cleanup(_) ->
    boss_db:pop(),
    ok.

issue_validation_case() ->
    [Project|_] = boss_db:find(boss_reference_project, [], [{limit, 1}]),
    Issue = boss_reference_issue:new(id, [], "body", "open", Project:id(),
                                     undefined, calendar:universal_time()),
    {error, Errors} = Issue:validate(),
    ?assert(lists:member("Title is required", Errors)).

association_case() ->
    [Issue|_] = boss_db:find(boss_reference_issue,
                             [{title, 'equals', "Broken link on dashboard"}]),
    ?assertEqual("Legacy Baseline", (Issue:project()):name()),
    ?assertEqual("Reference Member", (Issue:assignee()):display_name()),
    ?assertEqual(2, length((Issue:project()):issues())),
    ?assertEqual(1, length(Issue:comments())),
    ?assert(lists:any(fun(Label) -> Label:name() =:= "regression" end,
                      Issue:labels())).

authentication_case() ->
    {ok, Owner} = boss_reference_auth:find_user("owner"),
    ?assertEqual({ok, Owner}, boss_reference_auth:authenticate("owner", "owner")),
    ?assertEqual(error, boss_reference_auth:authenticate("owner", "wrong")),
    ?assertEqual("/", boss_reference_auth:safe_return_to("//evil.example")),
    ?assertEqual("/projects/legacy-baseline",
                 boss_reference_auth:safe_return_to("/projects/legacy-baseline")).

test_support_case() ->
    Body = <<"<input type=\"hidden\" value=\"TOKEN\" "
             "name=\"csrfmiddlewaretoken\" />">>,
    Headers = [{"Set-Cookie", "csrf_token=TOKEN; Path=/"},
               {"Set-Cookie", "_boss_session=SESSION; Path=/"}],
    ?assertEqual("TOKEN", boss_reference_test_support:csrf_token(Body)),
    ?assertEqual("csrf_token=TOKEN; _boss_session=SESSION",
                 boss_reference_test_support:cookie_header(Headers)),
    ?assertEqual("SESSION",
                 boss_reference_test_support:cookie_value("_boss_session",
                                                          Headers)),
    ?assertEqual("title=hello+world",
                 boss_reference_test_support:urlencode_form(
                   [{"title", "hello world"}])),
    ?assertEqual("csrfmiddlewaretoken=TOKEN&title=hello+world",
                 boss_reference_test_support:csrf_form(
                   [{"title", "hello world"}], "TOKEN")),
    ?assertEqual("title=hello+world",
                 boss_reference_test_support:csrf_form_without_token(
                   [{"title", "hello world"}])),
    ?assert(string:str(
              boss_reference_test_support:csrf_form_with_wrong_token([]),
              "deliberately-wrong-token") > 0).

bounded_invariant_case() ->
    lists:foreach(fun(Status) ->
                          ?assertNotEqual(error,
                                          boss_reference_domain:issue_status(Status))
                  end, ["open", "closed"]),
    lists:foreach(fun(Label) ->
                          Normalized = boss_reference_domain:normalize_label(Label),
                          ?assertEqual(match,
                                       re:run(Normalized,
                                              "^[a-z]+$", [{capture, none}]))
                  end, ["alpha", "beta", "gamma", "delta"]).

websocket_malformed_message_case() ->
    Handler = boss_reference_activity_websocket:new(undefined, undefined),
    {ok, State} = Handler:init(),
    {noreply, SameState} = Handler:handle_incoming(
                              "/websocket/activity", self(), <<"not-json">>, State),
    ?assertEqual(State, SameState),
    receive
        _Unexpected -> ?assert(false)
    after 0 -> ok
    end.

websocket_broadcast_case() ->
    Handler = boss_reference_activity_websocket:new(undefined, undefined),
    {ok, State} = Handler:init(),
    {noreply, SameState} = Handler:handle_broadcast(
                              {issue_created, "missing-project", "issue-1"}, State),
    ?assertEqual(State, SameState).
