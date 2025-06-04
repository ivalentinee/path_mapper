%{
  configs: [
    %{
      name: "default",
      color: true,
      strict: true,
      files: %{
        included: ["lib/", "test/", "config/", "priv/"],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          "test/support/*.ex",
          "lib/path_mapper_web/components/core_components.ex"
        ]
      },
      checks: [
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Design.TagFIXME, false}
      ]
    }
  ]
}
