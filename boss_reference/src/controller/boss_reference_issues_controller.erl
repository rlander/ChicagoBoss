-module(boss_reference_issues_controller, [Req, SessionID]).
-compile(tuple_calls).

-compile(export_all).

before_(Action, _Method, _Tokens) ->
    Auth = boss_reference_auth:current_user(SessionID),
    case {requires_login(Action), Auth} of
        {false, _} -> {ok, Auth};
        {true, {ok, _User}} -> {ok, Auth};
        {true, anonymous} ->
            {redirect, [{controller, "auth"},
                        {action, "login"},
                        {return_to, Req:uri()}]}
    end.

index('GET', [], Auth) ->
    {ok, [{current_user, Auth},
          {user, boss_reference_auth:template_user(Auth)},
          {issues, filtered_issues(undefined)},
          {project, undefined},
          {filter_status, Req:query_param("status", "all")}]};
index('GET', [ProjectSlug], Auth) ->
    case project_by_slug(ProjectSlug) of
        {ok, Project} ->
            {ok, [{current_user, Auth},
                  {user, boss_reference_auth:template_user(Auth)},
                  {issues, filtered_issues(Project:id())},
                  {project, Project},
                  {filter_status, Req:query_param("status", "all")}]};
        not_found -> {404, "Project not found", []}
    end.

show('GET', [Id], Auth) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            {ok, [{current_user, Auth},
                  {user, boss_reference_auth:template_user(Auth)},
                  {issue, Issue},
                  {project, Issue:project()},
                  {comments, Issue:comments()},
                  {labels, Issue:labels()},
                  {errors, []}]};
        not_found -> {404, "Issue not found", []}
    end.

create('GET', [ProjectSlug], Auth) ->
    case project_by_slug(ProjectSlug) of
        {ok, Project} ->
            {ok, [{current_user, Auth},
                  {user, boss_reference_auth:template_user(Auth)},
                  {project, Project},
                  {issue, new_issue(Project:id())},
                  {errors, []}]};
        not_found -> {404, "Project not found", []}
    end;
create('POST', [ProjectSlug], {ok, User}) ->
    case project_by_slug(ProjectSlug) of
        {ok, Project} ->
            Title = Req:post_param("title", ""),
            Body = Req:post_param("body", ""),
            AssigneeID = optional_param(Req:post_param("assignee_id", "")),
            Issue0 = boss_reference_issue:new(
                       id, Title, Body, "open", Project:id(), AssigneeID,
                       calendar:universal_time()),
            case boss_reference_auth:can_create({ok, User}, Project:id()) of
                false -> {401, "Issue creation is not permitted", []};
                true ->
                    case Issue0:save() of
                        {ok, Issue} ->
                            broadcast({issue_created, Project:id(), Issue:id()}),
                            boss_flash:add(SessionID, notice, "Issue created"),
                            {redirect, issue_location(Issue)};
                        {error, Errors} ->
                            {ok, [{current_user, {ok, User}},
                                  {user, User},
                                  {project, Project},
                                  {issue, Issue0},
                                  {errors, Errors}]}
                    end
            end;
        not_found -> {404, "Project not found", []}
    end.

update('GET', [Id], Auth) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            {ok, [{current_user, Auth},
                  {user, boss_reference_auth:template_user(Auth)},
                  {project, Issue:project()},
                  {issue, Issue}, {errors, []}]};
        not_found -> {404, "Issue not found", []}
    end;
update('POST', [Id], {ok, User}) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            case boss_reference_auth:can_edit({ok, User}, Issue:project_id()) of
                false -> {401, "Issue editing is not permitted", []};
                true ->
                    Updated = Issue:set(
                                boss_reference_domain:issue_attributes(
                                  Req:post_param("title", Issue:title()),
                                  Req:post_param("body", Issue:body()),
                                  Req:post_param("status", Issue:status()),
                                  Issue:project_id())),
                    case Updated:save() of
                        {ok, Saved} ->
                            broadcast({issue_updated, Saved:project_id(),
                                       Saved:id()}),
                            boss_flash:add(SessionID, notice, "Issue updated"),
                            {redirect, issue_location(Saved)};
                        {error, Errors} ->
                            {ok, [{current_user, {ok, User}},
                                  {user, User},
                                  {project, Issue:project()},
                                  {issue, Updated}, {errors, Errors}]}
                    end
            end;
        not_found -> {404, "Issue not found", []}
    end.

close('POST', [Id], {ok, User}) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            case boss_reference_auth:can_close({ok, User}, Issue) of
                false -> {401, "Issue closing is not permitted", []};
                true ->
                    Updated = Issue:set([{status, close_status(Issue:status())}]),
                    {ok, Saved} = Updated:save(),
                    broadcast({issue_closed, Saved:project_id(), Saved:id()}),
                    boss_flash:add(SessionID, notice, "Issue status updated"),
                    {redirect, issue_location(Saved)}
            end;
        not_found -> {404, "Issue not found", []}
    end.

comment('POST', [Id], {ok, User}) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            Body = Req:post_param("body", ""),
            Comment0 = boss_reference_comment:new(
                         id, Body, Issue:id(), User:id(),
                         calendar:universal_time()),
            case boss_reference_auth:can_comment({ok, User}, Issue:id()) of
                false -> {401, "Commenting is not permitted", []};
                true ->
                    case Comment0:save() of
                        {ok, Comment} ->
                            broadcast({comment_added, Issue:project_id(), Comment:id()}),
                            boss_flash:add(SessionID, notice, "Comment added"),
                            {redirect, issue_location(Issue)};
                        {error, Errors} ->
                            {ok, [{current_user, {ok, User}},
                                  {user, User},
                                  {project, Issue:project()},
                                  {issue, Issue}, {comments, Issue:comments()},
                                  {errors, Errors}]}
                    end
            end;
        not_found -> {404, "Issue not found", []}
    end.

labels('POST', [Id], {ok, User}) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            case boss_reference_auth:can_edit({ok, User}, Issue:project_id()) of
                false -> {401, "Label editing is not permitted", []};
                true ->
                    LabelName = Req:post_param("label", ""),
                    case LabelName of
                        "" ->
                            {ok, [{current_user, {ok, User}},
                                  {user, User},
                                  {project, Issue:project()},
                                  {issue, Issue}, {errors, ["Label is required"]}]};
                        _ ->
                            add_label(Issue, User, LabelName)
                    end
            end;
        not_found -> {404, "Issue not found", []}
    end.

add_label(Issue, User, LabelName) ->
    case boss_reference_domain:find_label(LabelName) of
        {ok, Label} ->
                            boss_reference_domain:add_label(Issue, Label),
                            boss_flash:add(SessionID, notice, "Label added"),
                            {redirect, issue_location(Issue)};
        not_found ->
            case (boss_reference_label:new(
                    id, LabelName,
                    boss_reference_domain:normalize_label(LabelName))):save() of
                {ok, Label0} ->
                    boss_reference_domain:add_label(Issue, Label0),
                    {redirect, issue_location(Issue)};
                {error, Errors} ->
                    {ok, [{current_user, {ok, User}},
                          {user, User},
                          {project, Issue:project()},
                          {issue, Issue}, {errors, Errors}]}
            end
    end.

api('GET', [Id], _Auth) ->
    case boss_reference_domain:find_issue(Id) of
        {ok, Issue} ->
            {json, [{id, Issue:id()},
                    {title, Issue:title()},
                    {status, Issue:status()},
                    {project_id, Issue:project_id()},
                    {labels, [list_to_binary(Label:name()) ||
                               Label <- Issue:labels()]}]};
        not_found -> {404, "Issue not found", []}
    end.

requires_login("create") -> true;
requires_login("update") -> true;
requires_login("close") -> true;
requires_login("comment") -> true;
requires_login("labels") -> true;
requires_login(_) -> false.

project_by_slug(Slug) ->
    case boss_db:find(boss_reference_project,
                      [{slug, 'equals', Slug}], [{limit, 1}]) of
        [Project|_] -> {ok, Project};
        [] -> not_found
    end.

filtered_issues(undefined) ->
    filtered_issues([], []);
filtered_issues(ProjectID) ->
    filtered_issues([{project_id, 'equals', ProjectID}], []).

filtered_issues(Conditions, _Unused) ->
    Status = Req:query_param("status", "all"),
    Conditions1 = case boss_reference_domain:issue_status(Status) of
        {ok, Normalized} -> [{status, 'equals', Normalized}|Conditions];
        error -> Conditions
    end,
    boss_db:find(boss_reference_issue, Conditions1,
                 [{order_by, created_at}, {descending, true}]).

new_issue(ProjectID) ->
    boss_reference_issue:new(id, "", "", "open", ProjectID, undefined,
                             calendar:universal_time()).

optional_param("") -> undefined;
optional_param(undefined) -> undefined;
optional_param(Value) -> Value.

close_status("open") -> "closed";
close_status("closed") -> "open";
close_status(_) -> "open".

issue_location(Issue) ->
    "/issues/" ++ Issue:id().

broadcast(Message) ->
    case global:whereis_name(boss_reference_activity_websocket) of
        undefined -> ok;
        _Pid -> boss_service_worker:broadcast(boss_reference_activity_websocket, Message)
    end.
