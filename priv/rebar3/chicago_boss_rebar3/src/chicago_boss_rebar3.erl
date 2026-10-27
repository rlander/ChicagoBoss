%% Rebar3 provider for legacy Chicago Boss applications.
%%
%% Rebar3 owns dependency resolution and the framework's normal source
%% compilation. The provider is deliberately only a bridge: application
%% sources in the historical Chicago Boss directories are still compiled by
%% boss_load and the existing compiler adapters.
-module(chicago_boss_rebar3).

-behaviour(provider).

-export([init/1, do/1, format_error/1]).

-define(PROVIDER, chicago_boss_compile).

init(State) ->
    Provider = providers:create([
        {name, ?PROVIDER},
        {module, ?MODULE},
        {bare, true},
        {deps, [{default, compile}]},
        {example, "rebar3 chicago_boss_compile"},
        {short_desc, "Compile legacy Chicago Boss application sources"},
        {desc, "Compile controllers, models, libraries and views through the historical Chicago Boss compiler"},
        {opts, []}
    ]),
    {ok, rebar_state:add_provider(State, Provider)}.

do(State) ->
    case application_name(State) of
        {ok, AppName} ->
            case is_project_application(State, AppName) andalso
                 is_legacy_application() of
                true -> compile_legacy_application(State, AppName);
                false -> {ok, State}
            end;
        {error, not_found} ->
            {ok, State}
    end.

is_project_application(State, AppName) ->
    case rebar_state:current_app(State) of
        undefined ->
            true;
        CurrentApp ->
            CurrentName = rebar_app_info:name(CurrentApp),
            CurrentName =:= AppName orelse
            CurrentName =:= list_to_binary(atom_to_list(AppName))
    end.

format_error({chicago_boss_compile_failed, AppName, Reason}) ->
    io_lib:format("Chicago Boss compilation failed for ~p: ~p", [AppName, Reason]);
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

compile_legacy_application(State, AppName) ->
    OutDir = filename:join([rebar_dir:base_dir(State),
                             "lib", atom_to_list(AppName), "ebin"]),
    ok = filelib:ensure_dir(filename:join(OutDir, "placeholder")),
    add_project_code_paths(State, OutDir),
    ok = copy_priv_dir(OutDir),
    case boss_load:load_all_modules_and_emit_app_file(AppName, OutDir) of
        ok ->
            rebar_api:info("Chicago Boss legacy compilation completed for ~p", [AppName]),
            {ok, State};
        {error, Reason} ->
            {error, {chicago_boss_compile_failed, AppName, Reason}};
        Other ->
            {error, {chicago_boss_compile_failed, AppName, Other}}
    end.

copy_priv_dir(OutDir) ->
    SourceDir = filename:absname("priv"),
    TargetDir = filename:join(filename:dirname(OutDir), "priv"),
    case filelib:is_dir(SourceDir) of
        false ->
            ok;
        true ->
            SourceParts = filename:split(filename:absname(SourceDir)),
            filelib:fold_files(
                SourceDir,
                ".*",
                true,
                fun(Source, ok) ->
                    RelativeParts = lists:nthtail(
                        length(SourceParts), filename:split(filename:absname(Source))),
                    Relative = filename:join(RelativeParts),
                    Target = filename:join(TargetDir, Relative),
                    ok = filelib:ensure_dir(Target),
                    case file:copy(Source, Target) of
                        {ok, _Bytes} -> ok;
                        ok -> ok
                    end
                end,
                ok)
    end.

add_project_code_paths(State, OutDir) ->
    %% Dependencies are already fetched and compiled by the time a post
    %% compile provider runs. Add their ebin directories explicitly so the
    %% existing compiler adapters see boss_db, erlydtl and their transforms.
    _ = rebar_api:add_deps_to_path(State),
    _ = code:add_patha(OutDir),
    ok.

application_name(_State) ->
    AppSrcs = filelib:wildcard(filename:join(["src", "*.app.src"])) ++
              filelib:wildcard(filename:join(["src", "boss", "*.app.src"])),
    case AppSrcs of
        [AppSrc|_] ->
            case file:consult(AppSrc) of
                {ok, [{application, AppName, _}]} when is_atom(AppName) ->
                    {ok, AppName};
                {ok, [{application, AppName, _}|_]} when is_atom(AppName) ->
                    {ok, AppName};
                _ ->
                    {error, not_found}
            end;
        [] ->
            {error, not_found}
    end.

is_legacy_application() ->
    lists:any(fun filelib:is_dir/1,
              ["src/controller", "src/model", "src/view", "src/mail", "src/lib"]).
