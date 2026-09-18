defmodule PathMapper.Api.Document do
  @moduledoc """
  The API contract, read from `priv/api` and resolved once at boot.

  The resolved document is both what `PathMapperWeb.Plugs.SchemaGate` enforces and
  what `GET /api/openapi.json` serves, so a client cannot read one contract and be
  judged against another.
  """

  @key __MODULE__
  @index "index.yaml"
  @verbs ~w(get post put patch delete)

  defmodule Operation do
    @moduledoc false
    defstruct [:method, :segments, :schemas]
  end

  @doc """
  Reads and resolves the document, then stores it.

  Raises on a malformed or cyclic document: a contract the server cannot read is a
  reason not to start, not something to serve.
  """
  def load! do
    contract = resolve!()
    :persistent_term.put(@key, {contract, operations(contract)})
    :ok
  end

  @doc "The resolved contract, as it is served."
  def contract do
    {contract, _operations} = :persistent_term.get(@key)
    contract
  end

  @doc "The operation a method and path name, or nil when the document has none."
  def operation(method, path) do
    {_contract, operations} = :persistent_term.get(@key)
    segments = split(path)

    Enum.find(operations, fn operation ->
      operation.method == method and matches?(operation.segments, segments)
    end)
  end

  @doc """
  Checks that the router and the document describe the same set of routes.

  Phoenix matches a route before any pipeline runs, so the gate never sees a
  request for a path the router does not have. The document can therefore only be
  held to the route table at boot, and this is where that happens: an undescribed
  route and a described route that does not exist are both reasons not to start.
  """
  def verify_routes!(routes) do
    routed = MapSet.new(routes, fn route -> {verb(route), route.path} end)
    described = MapSet.new(described_routes())

    complain!("the document does not describe", MapSet.difference(routed, described))
    complain!("the router does not serve", MapSet.difference(described, routed))

    :ok
  end

  defp verb(route), do: route.verb |> Atom.to_string() |> String.upcase()

  defp described_routes do
    {contract, _operations} = :persistent_term.get(@key)

    for {path, verbs} <- Map.get(contract, "paths", %{}),
        {verb, _operation} <- verbs,
        verb in @verbs,
        do: {String.upcase(verb), phoenix_path(path)}
  end

  # OpenAPI writes a path parameter as {name}; Phoenix writes it as :name.
  defp phoenix_path(path), do: Regex.replace(~r/\{([^}]+)\}/, path, ":\\1")

  defp complain!(what, difference) do
    if MapSet.size(difference) > 0 do
      listing = difference |> Enum.sort() |> Enum.map_join(", ", fn {v, p} -> "#{v} #{p}" end)
      raise ArgumentError, "routes #{what}: #{listing}"
    end
  end

  @doc "Resolves a document tree without storing it. Takes a directory so tests can point elsewhere."
  def resolve!(directory \\ directory()) do
    file = Path.join(directory, @index)
    inline(read!(file), file, [])
  end

  defp directory, do: Path.join(:code.priv_dir(:path_mapper), "api")

  # Resolution

  defp inline(%{"$ref" => ref} = node, file, stack) when map_size(node) == 1 do
    {target, pointer} = target(ref, file)
    entry = {target, pointer}

    if entry in stack do
      raise ArgumentError, "cyclic $ref in the API document: #{describe(entry)}"
    end

    target
    |> read!()
    |> fetch!(pointer, target)
    |> inline(target, [entry | stack])
  end

  defp inline(node, file, stack) when is_map(node) do
    Map.new(node, fn {key, value} -> {key, inline(value, file, stack)} end)
  end

  defp inline(node, file, stack) when is_list(node) do
    Enum.map(node, &inline(&1, file, stack))
  end

  defp inline(node, _file, _stack), do: node

  defp target(ref, file) do
    {path, fragment} =
      case String.split(ref, "#", parts: 2) do
        [path] -> {path, ""}
        [path, fragment] -> {path, fragment}
      end

    {resolve_path(path, file), pointer(fragment)}
  end

  defp resolve_path("", file), do: file
  defp resolve_path(path, file), do: Path.expand(Path.join(Path.dirname(file), path))

  defp pointer(""), do: []
  defp pointer("/" <> rest), do: String.split(rest, "/")

  defp fetch!(document, [], _file), do: document

  defp fetch!(document, pointer, file) do
    case get_in(document, pointer) do
      nil -> raise ArgumentError, "#{file} has no #{Enum.join(pointer, "/")}"
      value -> value
    end
  end

  defp describe({file, pointer}), do: "#{file}##{Enum.join(pointer, "/")}"

  defp read!(file) do
    case YamlElixir.read_from_file(file) do
      {:ok, document} -> document
      {:error, reason} -> raise ArgumentError, "#{file} is not readable YAML: #{inspect(reason)}"
    end
  end

  # Operations

  defp operations(contract) do
    for {path, verbs} <- Map.get(contract, "paths", %{}),
        {verb, operation} <- verbs,
        verb in @verbs do
      %Operation{
        method: String.upcase(verb),
        segments: template(path),
        schemas: schemas(operation)
      }
    end
  end

  defp template(path) do
    Enum.map(split(path), fn
      "{" <> rest -> {:parameter, String.trim_trailing(rest, "}")}
      segment -> {:literal, segment}
    end)
  end

  defp split(path), do: path |> String.split("/", trim: true)

  defp schemas(operation) do
    operation
    |> get_in(["requestBody", "content"])
    |> Kernel.||(%{})
    |> Map.new(fn {type, body} -> {type, ExJsonSchema.Schema.resolve(body["schema"] || %{})} end)
  end

  defp matches?(template, segments) when length(template) == length(segments) do
    Enum.zip(template, segments)
    |> Enum.all?(fn
      {{:literal, expected}, actual} -> expected == actual
      {{:parameter, _name}, _actual} -> true
    end)
  end

  defp matches?(_template, _segments), do: false
end
