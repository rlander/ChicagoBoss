-module(boss_reference_label,
        [Id, Name::string(), Slug::string()]).
-compile(tuple_calls).

-compile(export_all).

-has({issue_labels, many,
      [{module, boss_reference_issue_label}, {foreign_key, label_id}]}).

validation_tests() ->
    [{fun() -> Name =/= undefined andalso Name =/= [] end,
      "Label name is required"},
     {fun() -> length(Name) =< 40 end, "Label name is too long"},
     {fun() -> Slug =/= undefined andalso Slug =/= [] end,
      "Label slug is required"}].

validation_tests(on_create) -> validation_tests();
validation_tests(on_update) -> validation_tests().
