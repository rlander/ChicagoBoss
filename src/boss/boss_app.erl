%%-------------------------------------------------------------------
%% @author
%%     ChicagoBoss Team and contributors, see AUTHORS file in root directory
%% @end
%% @copyright
%%     This file is part of ChicagoBoss project.
%%     See AUTHORS file in root directory
%%     for license information, see LICENSE file in root directory
%% @end
%% @doc Callbacks for the rr application.
%%-------------------------------------------------------------------

-module(boss_app).

-behaviour(application).
-export([start/2,stop/1]).


%% @spec start(_Type, _StartArgs) -> ServerRet
%% @doc application start callback for boss.
start(_Type, _StartArgs) ->
    case maybe_start_reloader() of
        ok ->
            boss_sup:start_link();
        {error, Reason} ->
            {error, {reloader_start_failed, Reason}}
    end.

%% Rebar3 3.15.2 loads the shell sys.config but does not pass a configured
%% vm_args file to the shell VM. Start the historical MochiWeb reloader from
%% the Boss application callback instead, and only when the application has
%% explicitly selected a developing app. This preserves production startup.
maybe_start_reloader() ->
    case application:get_env(boss, developing_app) of
        {ok, AppName} when is_atom(AppName) ->
            case reloader:start() of
                {ok, _Pid} ->
                    ok;
                {error, {already_started, _Pid}} ->
                    ok;
                Other ->
                    {error, Other}
            end;
        _ ->
            ok
    end.

%% @spec stop(_State) -> ServerRet
%% @doc application stop callback for boss.
stop(_State) ->
    ok.
