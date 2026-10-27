-module(boss_reference_auth_controller, [Req, SessionID]).
-compile(tuple_calls).

-compile(export_all).

before_(_Action, _Method, _Tokens) ->
    {ok, boss_reference_auth:current_user(SessionID)}.

login('GET', [], Auth) ->
    {ok, [{current_user, Auth},
          {user, boss_reference_auth:template_user(Auth)},
          {return_to, boss_reference_auth:safe_return_to(
                       Req:query_param("return_to", "/"))}]};
login('POST', [], _Auth) ->
    Username = Req:post_param("username", ""),
    Password = Req:post_param("password", ""),
    ReturnTo = boss_reference_auth:safe_return_to(
                 Req:post_param("return_to", "/")),
    case boss_reference_auth:authenticate(Username, Password) of
        {ok, User} ->
            ok = boss_session:set_session_data(SessionID, user_id, User:id()),
            boss_flash:add(SessionID, notice, "Signed in",
                           "Welcome back, " ++ User:display_name()),
            {redirect, ReturnTo};
        error ->
            {ok, [{error, "Invalid username or password"},
                  {user, undefined},
                  {username, Username},
                  {return_to, ReturnTo}]}
    end.

logout('POST', [], _Auth) ->
    logout_user().

logout_user() ->
    ok = boss_session:delete_session(SessionID),
    {redirect, [{controller, "home"}, {action, "index"}]}.
