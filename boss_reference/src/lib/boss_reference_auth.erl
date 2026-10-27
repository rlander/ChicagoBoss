-module(boss_reference_auth).
-compile(tuple_calls).

-export([password_hash/1,
         current_user/1,
         template_user/1,
         authenticate/2,
         find_user/1,
         safe_return_to/1,
         can_create/2,
         can_edit/2,
         can_close/2,
         can_comment/2,
         is_owner/2]).

password_hash(Password) when is_list(Password) ->
    crypto:hash(sha256, list_to_binary(Password));
password_hash(Password) when is_binary(Password) ->
    crypto:hash(sha256, Password).

find_user(Username) ->
    case boss_db:find(boss_reference_user,
                      [{username, 'equals', Username}],
                      [{limit, 1}]) of
        [User|_] -> {ok, User};
        [] -> not_found
    end.

authenticate(Username, Password) ->
    case find_user(Username) of
        {ok, User} ->
            case User:active() andalso
                 User:password_hash() =:= password_hash(Password) of
                true -> {ok, User};
                false -> error
            end;
        not_found -> error
    end.

current_user(undefined) ->
    anonymous;
current_user(SessionID) ->
    case boss_session:get_session_data(SessionID, user_id) of
        undefined -> anonymous;
        UserID ->
            case boss_db:find(UserID) of
                undefined -> anonymous;
                User ->
                    case User:active() of
                        true -> {ok, User};
                        false -> anonymous
                    end
            end
    end.

template_user({ok, User}) -> User;
template_user(anonymous) -> undefined.

safe_return_to(undefined) -> "/";
safe_return_to(<<>>) -> "/";
safe_return_to(ReturnTo) when is_binary(ReturnTo) ->
    safe_return_to(binary_to_list(ReturnTo));
safe_return_to([$/|Rest] = ReturnTo) ->
    case Rest of
        [$/|_] -> "/";
        _ -> ReturnTo
    end;
safe_return_to(_) -> "/".

can_create({ok, User}, ProjectID) ->
    User:active() andalso boss_db:find(ProjectID) =/= undefined;
can_create(_, _) ->
    false.

can_edit({ok, User}, ProjectID) ->
    User:active() andalso is_owner(User, ProjectID);
can_edit(_, _) ->
    false.

can_close(User, Issue) when is_tuple(Issue) ->
    can_edit(User, Issue:project_id());
can_close(User, IssueID) ->
    case boss_db:find(IssueID) of
        undefined -> false;
        Issue -> can_close(User, Issue)
    end.

can_comment({ok, User}, IssueID) ->
    User:active() andalso boss_db:find(IssueID) =/= undefined;
can_comment(_, _) ->
    false.

is_owner(User, ProjectID) ->
    case boss_db:find(ProjectID) of
        undefined -> false;
        Project ->
            User:id() =:= Project:owner_id() orelse User:role() =:= "owner"
    end.
