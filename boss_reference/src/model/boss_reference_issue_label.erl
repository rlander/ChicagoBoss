-module(boss_reference_issue_label,
        [Id, IssueId, LabelId]).
-compile(tuple_calls).

-compile(export_all).

-belongs_to(issue).
-belongs_to(label).

validation_tests() ->
    [{fun() -> IssueId =/= undefined andalso boss_db:find(IssueId) =/= undefined end,
      "Issue must exist"},
     {fun() -> LabelId =/= undefined andalso boss_db:find(LabelId) =/= undefined end,
      "Label must exist"}].

validation_tests(on_create) -> validation_tests();
validation_tests(on_update) -> validation_tests().
