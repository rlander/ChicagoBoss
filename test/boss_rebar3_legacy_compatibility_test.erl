-module(boss_rebar3_legacy_compatibility_test).

-include_lib("eunit/include/eunit.hrl").

legacy_chicago_boss_pipeline_test_() ->
    {setup,
     fun compile_fixture/0,
     fun cleanup_fixture/1,
     fun(State) ->
         [fun() -> parameterized_controller_test(State) end,
          fun() -> session_controller_test(State) end,
          fun() -> route_metadata_and_router_test(State) end,
          fun() -> boss_record_and_database_test(State) end,
          fun() -> erlydtl_view_test(State) end]
     end}.

compile_fixture() ->
    PreviousCwd = filename:absname("."),
    Fixture = filename:absname(filename:join(["fixtures", "legacy_app"])),
    ok = file:set_cwd(Fixture),
    OutDir = filename:join([Fixture, "_build", "ebin"]),
    ok = filelib:ensure_dir(filename:join(OutDir, "placeholder")),
    ok = case boss_load:load_all_modules_and_emit_app_file(legacy_compat, OutDir) of
        ok -> ok;
        Error -> erlang:error({legacy_fixture_compile_failed, Error})
    end,
    true = code:add_patha(OutDir),
    ok = file:set_cwd(PreviousCwd),
    #{fixture => Fixture, previous_cwd => PreviousCwd, out_dir => OutDir}.

cleanup_fixture(#{previous_cwd := PreviousCwd}) ->
    ok = file:set_cwd(PreviousCwd),
    ok.

parameterized_controller_test(_State) ->
    Info = controller_info(legacy_compat_legacy_controller),
    Context = [{request, {request, index}},
               {action, "index"}, {method, 'GET'}, {tokens, []}],
    ?assertEqual({output, {index, {request, index}}},
                 boss_controller_adapter_pmod:action(Info, Context)),
    ?assertEqual({ok, [{'_before', undefined}|Context]},
                 boss_controller_adapter_pmod:before_filter(Info, Context)),
    ?assertEqual({after_hook, {output, ok}},
                 boss_controller_adapter_pmod:after_filter(Info, Context, {output, ok})),
    ?assertEqual({configured, default},
                 boss_controller_adapter_pmod:filter_config(Info, cache, default, Context)),
    ?assertEqual({output, {show, "abc", {request, show}}},
                 boss_controller_adapter_pmod:action(
                   Info,
                   [{request, {request, show}}, {action, "show"},
                    {method, 'GET'}, {tokens, ["abc"]}])).

session_controller_test(_State) ->
    Info = controller_info(legacy_compat_session_controller),
    ?assertEqual({output, {session, {request, session}, "session-1"}},
                 boss_controller_adapter_pmod:action(
                   Info,
                   [{request, {request, session}}, {session_id, "session-1"},
                    {action, "index"}, {method, 'GET'}, {tokens, []}])).

route_metadata_and_router_test(#{fixture := Fixture}) ->
    ?assertEqual([{index, []}, {show, ['Id']}, {after_, []}, {config, []}],
                 legacy_compat_legacy_controller:'_routes'({request, route})),
    ?assertEqual({["abc"], []},
                 boss_controller_lib:convert_params_to_tokens(
                   [{id, "abc"}], legacy_compat_legacy_controller, show)),
    PreviousCwd = filename:absname("."),
    ok = file:set_cwd(Fixture),
    application:set_env(boss, developing_app, legacy_compat),
    put(boss_environment, development),
    Controllers = ["legacy_compat_legacy_controller", "legacy_compat_session_controller"],
    {ok, State} = boss_router_controller:init(
                    [{application, legacy_compat}, {controllers, Controllers}]),
    {reply, Routed, _} = boss_router_controller:handle_call(
                           {route, "/legacy/abc"}, self(), State),
    ?assertEqual({ok, {legacy_compat, "legacy", "show", ["abc"]}}, Routed),
    {reply, Reverse, _} = boss_router_controller:handle_call(
                            {unroute, "health", "index", []}, self(), State),
    ?assertEqual("/health", Reverse),
    ok = file:set_cwd(PreviousCwd).

boss_record_and_database_test(_State) ->
    ensure_database_started(),
    Person = legacy_compat_person:new(id, "Ada"),
    ?assertEqual([{id, id}, {name, "Ada"}], legacy_compat_person:attributes(Person)),
    {ok, Saved} = legacy_compat_person:save(Person),
    Id = legacy_compat_person:id(Saved),
    ?assertEqual(Saved, boss_db:find(Id)).

erlydtl_view_test(_State) ->
    {ok, Body} = legacy_compat_view_health_index_html:render([{name, "Ada"}]),
    ?assertNotEqual(nomatch, binary:match(iolist_to_binary(Body), <<"Ada">>)).

controller_info(Module) ->
    {Module, [{atom_to_list(Function), Arity} ||
              {Function, Arity} <- Module:module_info(exports)]}.

ensure_database_started() ->
    case whereis(boss_db_sup) of
        undefined ->
            {ok, _} = boss_db:start([{adapter, mock}, {is_master_node, true},
                                     {cache_enable, false}, {shards, []}]);
        _Pid ->
            ok
    end,
    case global:whereis_name(boss_news) of
        undefined ->
            {ok, _} = boss_news:start([]);
        _NewsPid ->
            ok
    end.
