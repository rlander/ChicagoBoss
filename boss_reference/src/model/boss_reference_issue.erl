-module(boss_reference_issue,
        [Id,
         Title::string(),
         Body::string(),
         Status::string(),
         ProjectId,
         AssigneeId,
         CreatedAt::datetime()]).
-compile(tuple_calls).

-compile(export_all).

-belongs_to(project).
-belongs_to_user(assignee).
-has({comments, many,
      [{module, boss_reference_comment},
       {foreign_key, issue_id},
       {order_by, created_at}, {descending, false}]}).
-has({issue_labels, many,
      [{module, boss_reference_issue_label}, {foreign_key, issue_id}]}).

validation_tests() ->
    [{fun() -> Title =/= undefined andalso Title =/= [] end,
      "Title is required"},
     {fun() -> length(Title) =< 120 end, "Title is too long"},
     {fun() -> Body =/= undefined andalso Body =/= [] end,
      "Description is required"},
     {fun() -> lists:member(Status, ["open", "closed"]) end,
      "Status must be open or closed"},
     {fun valid_project/0, "Project must exist"},
     {fun valid_assignee/0, "Assignee must exist"}].

validation_tests(on_create) -> validation_tests();
validation_tests(on_update) -> validation_tests().

valid_project() ->
    ProjectId =/= undefined andalso boss_db:find(ProjectId) =/= undefined.

valid_assignee() ->
    AssigneeId =:= undefined orelse boss_db:find(AssigneeId) =/= undefined.

labels() ->
    [Label || Join <- issue_labels(),
              Label <- [Join:label()],
              Label =/= undefined].
