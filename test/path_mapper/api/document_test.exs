defmodule PathMapper.Api.DocumentTest do
  use ExUnit.Case, async: true

  alias PathMapper.Api.Document

  @nested "test/data/api/nested"
  @cyclic "test/data/api/cyclic"

  describe "resolve!/1" do
    test "inlines a reference to another file" do
      document = Document.resolve!(@nested)

      assert %{"title" => "Thing"} =
               get_in(document, [
                 "paths",
                 "/thing",
                 "post",
                 "requestBody",
                 "content",
                 "application/json",
                 "schema"
               ])
    end

    test "inlines a reference within the referenced file" do
      document = Document.resolve!(@nested)

      schema =
        get_in(document, [
          "paths",
          "/thing",
          "post",
          "requestBody",
          "content",
          "application/json",
          "schema"
        ])

      assert get_in(schema, ["properties", "tag", "enum"]) == ["red", "blue"]
    end

    test "inlines a fragment reference against the file holding it" do
      document = Document.resolve!(@nested)

      assert get_in(document, [
               "paths",
               "/thing",
               "post",
               "responses",
               "200",
               "content",
               "application/json",
               "schema",
               "required"
             ]) == ["id"]
    end

    test "leaves no reference behind" do
      refute @nested |> Document.resolve!() |> has_reference?()
    end

    test "raises on a cycle rather than looping" do
      assert_raise ArgumentError, ~r/cyclic \$ref/, fn -> Document.resolve!(@cyclic) end
    end

    test "raises when a fragment names nothing" do
      in_temporary_tree(
        %{
          "index.yaml" => "openapi: 3.0.3\npaths:\n  '/x': { $ref: '#/missing' }\n"
        },
        fn directory ->
          assert_raise ArgumentError, ~r/has no missing/, fn -> Document.resolve!(directory) end
        end
      )
    end
  end

  describe "the shipped document" do
    test "resolves" do
      refute Document.resolve!() |> has_reference?()
    end

    test "describes the map upload route" do
      document = Document.resolve!()
      assert Map.has_key?(document["paths"], "/api/scenes/map")
    end

    test "describes itself" do
      document = Document.resolve!()
      assert Map.has_key?(document["paths"], "/api/openapi.json")
    end

    test "gives every response of every route a description" do
      for {path, verbs} <- Document.resolve!()["paths"],
          {verb, operation} <- verbs,
          {status, response} <- operation["responses"] do
        assert is_binary(response["description"]) and response["description"] != "",
               "#{verb} #{path} #{status} has no description"
      end
    end

    test "gives every route a summary and a description" do
      for {path, verbs} <- Document.resolve!()["paths"], {verb, operation} <- verbs do
        assert is_binary(operation["summary"]), "#{verb} #{path} has no summary"
        assert is_binary(operation["description"]), "#{verb} #{path} has no description"
      end
    end
  end

  describe "operation/2" do
    test "finds a documented route" do
      assert %{method: "POST"} = Document.operation("POST", "/api/scenes/map")
    end

    test "does not find an undocumented path" do
      assert Document.operation("POST", "/api/scenes/nope") == nil
    end

    test "does not find a documented path under another method" do
      assert Document.operation("DELETE", "/api/scenes/map") == nil
    end
  end

  describe "verify_routes!/1" do
    test "accepts the routes the application actually serves" do
      routes =
        Enum.filter(PathMapperWeb.Router.__routes__(), &String.starts_with?(&1.path, "/api/"))

      assert Document.verify_routes!(routes) == :ok
    end

    test "raises on a route the document does not describe" do
      routes = [%{verb: :post, path: "/api/undescribed"}]

      assert_raise ArgumentError,
                   ~r/the document does not describe: POST \/api\/undescribed/,
                   fn ->
                     Document.verify_routes!(routes)
                   end
    end

    test "raises on a described route the router does not serve" do
      assert_raise ArgumentError, ~r/the router does not serve/, fn ->
        Document.verify_routes!([])
      end
    end
  end

  defp has_reference?(%{"$ref" => _}), do: true
  defp has_reference?(node) when is_map(node), do: Enum.any?(node, &has_reference?/1)
  defp has_reference?({_key, value}), do: has_reference?(value)
  defp has_reference?(node) when is_list(node), do: Enum.any?(node, &has_reference?/1)
  defp has_reference?(_node), do: false

  defp in_temporary_tree(files, function) do
    directory = Path.join(System.tmp_dir!(), "api-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)

    try do
      Enum.each(files, fn {name, body} -> File.write!(Path.join(directory, name), body) end)
      function.(directory)
    after
      File.rm_rf!(directory)
    end
  end
end
