defmodule PathMapper.ErrorsTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias PathMapper.Adventures.Loader, as: AdventureLoader
  alias PathMapper.Errors

  describe "format_load_error/1" do
    test "changeset with flat field errors" do
      changeset =
        {%{}, %{title: :string}}
        |> Changeset.cast(%{}, [:title])
        |> Changeset.validate_required([:title])

      {:error, changeset} = Changeset.apply_action(changeset, :insert)
      errors = Errors.format_load_error({:error, changeset})

      assert ["title: " <> _] = errors
    end

    test "changeset with nested embed errors produces human-readable paths" do
      # Load a malformed adventure to get a real changeset error
      AdventureLoader.load("bad-adventure.zip")
      |> Errors.format_load_error()
      |> then(fn errors ->
        assert Enum.any?(errors, &String.contains?(&1, "title"))
        assert Enum.any?(errors, &String.contains?(&1, "Scene #1"))
      end)
    end

    test "zip error" do
      errors = Errors.format_load_error({:error, {:zip, :einval}})
      assert [msg] = errors
      assert msg =~ "ZIP"
      assert msg =~ "einval"
    end

    test "toml error with line/column" do
      errors = Errors.format_load_error({:error, {:toml_parse_error, {3, 5, "bad key"}}})
      assert [msg] = errors
      assert msg =~ "line 3"
      assert msg =~ "column 5"
      assert msg =~ "bad key"
    end

    test "toml error without line/column" do
      errors = Errors.format_load_error({:error, {:toml_parse_error, :unexpected}})
      assert [msg] = errors
      assert msg =~ "manifest.toml"
    end

    test "string error" do
      errors = Errors.format_load_error({:error, "something went wrong"})
      assert errors == ["something went wrong"]
    end

    test "unknown error" do
      errors = Errors.format_load_error(:unexpected)
      assert [msg] = errors
      assert msg =~ "Unknown error"
    end
  end
end
