-module(boss_reference_domain).
-compile(tuple_calls).

-export([find_project/1,
         find_issue/1,
         find_label/1,
         issue_attributes/4,
         issue_status/1,
         normalize_label/1,
         add_label/2,
         remove_label/2,
         labels_for_issue/1]).

find_project(ProjectID) ->
    case boss_db:find(ProjectID) of
        Project when is_tuple(Project), element(1, Project) =:= boss_reference_project ->
            {ok, Project};
        _ -> not_found
    end.

find_issue(IssueID) ->
    case boss_db:find(IssueID) of
        Issue when is_tuple(Issue), element(1, Issue) =:= boss_reference_issue ->
            {ok, Issue};
        _ -> not_found
    end.

find_label(NameOrID) ->
    case boss_db:find(NameOrID) of
        Label when is_tuple(Label), element(1, Label) =:= boss_reference_label ->
            {ok, Label};
        _ ->
            case boss_db:find(boss_reference_label,
                              [{slug, 'equals', normalize_label(NameOrID)}],
                              [{limit, 1}]) of
                [Label|_] -> {ok, Label};
                [] -> not_found
            end
    end.

issue_attributes(Title, Body, Status, ProjectID) ->
    [{title, Title}, {body, Body}, {status, Status}, {project_id, ProjectID}].

issue_status("open") -> {ok, "open"};
issue_status("closed") -> {ok, "closed"};
issue_status(<<"open">>) -> {ok, "open"};
issue_status(<<"closed">>) -> {ok, "closed"};
issue_status(_) -> error.

normalize_label(Label) when is_binary(Label) ->
    normalize_label(binary_to_list(Label));
normalize_label(Label) when is_list(Label) ->
    string:to_lower(string:join(string:tokens(Label, " \t\n"), "-"));
normalize_label(Label) ->
    normalize_label(io_lib:write(Label)).

add_label(Issue, Label) ->
    Existing = boss_db:find(boss_reference_issue_label,
                            [{issue_id, 'equals', Issue:id()},
                             {label_id, 'equals', Label:id()}]),
    case Existing of
        [_|_] -> {ok, existing};
        [] ->
            Join = boss_reference_issue_label:new(id, Issue:id(), Label:id()),
            case Join:save() of
                {ok, _} -> {ok, added};
                Error -> Error
            end
    end.

remove_label(Issue, Label) ->
    Joins = boss_db:find(boss_reference_issue_label,
                         [{issue_id, 'equals', Issue:id()},
                          {label_id, 'equals', Label:id()}]),
    lists:map(fun(Join) -> boss_db:delete(Join:id()) end, Joins),
    ok.

labels_for_issue(Issue) ->
    Issue:labels().
