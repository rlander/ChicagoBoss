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

-module(boss_erlydtl_tags).
-export([url/2]).

url(Variables, Options) ->
    ListVars = lists:map(fun
            ({K, V}) when is_binary(V) -> {K, binary_to_list(V)};
            ({K, V}) -> {K, V}
        end, Variables),
    ThisApp = proplists:get_value(application, Options),
    LinkedApp = proplists:get_value(application, ListVars, ThisApp),
    LinkedAppAtom = list_to_atom(lists:concat([LinkedApp])),
    ControllerList = boss_files:web_controller_list(LinkedApp),
    ThisController = proplists:get_value(controller, Options),
    LinkedController = proplists:get_value(controller, ListVars, ThisController),
    DefaultAction = case proplists:get_value(controller, ListVars) of
        undefined ->
            proplists:get_value(action, Options);
        _ ->
            undefined
    end,
    Action = proplists:get_value(action, ListVars, DefaultAction),

    CleanVars = lists:foldl(fun(Key, Vars) ->
                proplists:delete(Key, Vars)
        end, ListVars, [application, controller, action]),

    NoUndefinedVars = lists:foldl(fun
            ({_, undefined}, Acc) ->
                Acc;
            (KV, Acc) ->
                [KV|Acc]
        end, [], CleanVars),

    ProtocolPlusDomain = case ThisApp =:= LinkedApp of
        true -> "";
        false ->
            case boss_web:domains(LinkedAppAtom) of
                all -> "";
                Domains ->
                    UseSameDomain = case proplists:get_value(host, Options) of
                        undefined -> false;
                        DefinedHost ->
                            [H|_] = re:split(DefinedHost, ":", [{return, list}]),
                            lists:member(H, Domains)
                    end,
                    case UseSameDomain of
                        true -> "";
                        false -> "http://" ++ hd(Domains)
                    end
            end
    end,

    RouterPid = proplists:get_value(router_pid, Options),
    RouterAdapter = boss_env:router_adapter(),
    URL = RouterAdapter:unroute(RouterPid, LinkedAppAtom, ControllerList, LinkedController, Action, NoUndefinedVars),
    BaseURL = case proplists:get_value(base_url, Options) of
        undefined -> base_url_or_empty(LinkedAppAtom);
        %% The in-process functional harness intentionally uses an empty
        %% base URL and does not start the boss_web gen_server. Treat that
        %% value as an explicit empty prefix instead of making a runtime
        %% lookup that cannot succeed in the harness.
        "" -> "";
        ProvidedBaseURL ->
            ProvidedBaseURL
    end,
    ProtocolPlusDomain ++ BaseURL ++ URL.

base_url_or_empty(App) ->
    case catch boss_web:base_url(App) of
        {'EXIT', _} -> "";
        BaseURL -> BaseURL
    end.
