-module(boss_reference_home_controller, [Req, SessionID]).
-compile(tuple_calls).

-compile(export_all).

before_(_Action, _Method, _Tokens) ->
    {ok, boss_reference_auth:current_user(SessionID)}.

index('GET', [], Auth) ->
    {ok, [{current_user, Auth},
          {user, boss_reference_auth:template_user(Auth)},
          {project_count, boss_db:count(boss_reference_project)},
          {open_issue_count, boss_db:count(boss_reference_issue,
                                            [{status, 'equals', "open"}])},
          {recent_issues, boss_db:find(boss_reference_issue, [],
                                        [{limit, 5},
                                         {order_by, created_at},
                                         {descending, true}])}]}.

activity('GET', [], Auth) ->
    {ok, [{current_user, Auth},
          {user, boss_reference_auth:template_user(Auth)},
          {recent_issues, boss_db:find(boss_reference_issue, [],
                                        [{limit, 20},
                                         {order_by, created_at},
                                         {descending, true}])}]}.

not_found('GET', [], _Auth) ->
    {404, "Reference page not found", []}.
