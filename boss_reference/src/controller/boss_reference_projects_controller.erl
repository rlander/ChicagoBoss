-module(boss_reference_projects_controller, [Req, SessionID]).
-compile(tuple_calls).

-compile(export_all).

before_(Action, _Method, _Tokens) ->
    Auth = boss_reference_auth:current_user(SessionID),
    case {Action, Auth} of
        {"index", _} -> {ok, Auth};
        {"show", _} -> {ok, Auth};
        {_, {ok, _User}} -> {ok, Auth};
        {_, anonymous} ->
            {redirect, [{controller, "auth"},
                        {action, "login"},
                        {return_to, Req:uri()}]}
    end.

index('GET', [], Auth) ->
    {ok, [{current_user, Auth},
          {user, boss_reference_auth:template_user(Auth)},
          {projects, boss_db:find(boss_reference_project, [],
                                  [{order_by, name}, {descending, false}])}]}.

show('GET', [Slug], Auth) ->
    case boss_db:find(boss_reference_project,
                      [{slug, 'equals', Slug}], [{limit, 1}]) of
        [Project|_] ->
            {ok, [{current_user, Auth},
                  {user, boss_reference_auth:template_user(Auth)},
                  {project, Project},
                  {issues, Project:issues()},
                  {issue_count, length(Project:issues())}]};
        [] ->
            {404, "Project not found", []}
    end.

create('GET', [], {ok, User}) ->
    {ok, [{current_user, {ok, User}},
          {user, User},
          {project, new_project(User:id())},
          {errors, []}]};
create('POST', [], {ok, User}) ->
    Name = Req:post_param("name", ""),
    Slug = boss_reference_domain:normalize_label(
             Req:post_param("slug", Name)),
    Project0 = boss_reference_project:new(
                 id, Slug, Name, User:id(), calendar:universal_time()),
    case User:active() of
        false -> {401, "Project creation is not permitted", []};
        true ->
            case Project0:save() of
                {ok, Project} ->
                    boss_flash:add(SessionID, notice, "Project created"),
                    {redirect, [{controller, "projects"},
                                {action, "show"}, {slug, Project:slug()}]};
                {error, Errors} ->
                    {ok, [{current_user, {ok, User}},
                          {user, User},
                          {project, Project0}, {errors, Errors}]}
            end
    end.

edit('GET', [Slug], {ok, User}) ->
    case project_by_slug(Slug) of
        {ok, Project} ->
            case boss_reference_auth:can_edit({ok, User}, Project:id()) of
                true -> {ok, [{current_user, {ok, User}},
                              {user, User},
                              {project, Project}, {errors, []}]};
                false -> {401, "Project editing is not permitted", []}
            end;
        not_found -> {404, "Project not found", []}
    end;
edit('POST', [Slug], {ok, User}) ->
    case project_by_slug(Slug) of
        {ok, Project} ->
            case boss_reference_auth:can_edit({ok, User}, Project:id()) of
                true -> update_project(Project);
                false -> {401, "Project editing is not permitted", []}
            end;
        not_found -> {404, "Project not found", []}
    end.

new_project(OwnerID) ->
    boss_reference_project:new(id, "", "", OwnerID, calendar:universal_time()).

project_by_slug(Slug) ->
    case boss_db:find(boss_reference_project,
                      [{slug, 'equals', Slug}], [{limit, 1}]) of
        [Project|_] -> {ok, Project};
        [] -> not_found
    end.

update_project(Project) ->
    Name = Req:post_param("name", Project:name()),
    Slug = boss_reference_domain:normalize_label(
             Req:post_param("slug", Project:slug())),
    Updated = Project:set([{name, Name}, {slug, Slug}]),
    case Updated:save() of
        {ok, Saved} ->
            boss_flash:add(SessionID, notice, "Project updated"),
            {redirect, [{controller, "projects"},
                        {action, "show"}, {slug, Saved:slug()}]};
        {error, Errors} ->
            {ok, [{current_user, boss_reference_auth:current_user(SessionID)},
                  {user, boss_reference_auth:template_user(
                           boss_reference_auth:current_user(SessionID))},
                  {project, Updated}, {errors, Errors}]}
    end.
