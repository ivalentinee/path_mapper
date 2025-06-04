defmodule PathMapper.ORAReader.XML do
  require Record
  Record.defrecord(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))

  Record.defrecord(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  def get_children(element, name) when is_atom(name) do
    Enum.filter(xmlElement(element, :content), fn child_element ->
      xmlElement(child_element, :name) == name
    end)
  end

  def get_attribute_value(element, attribute_name) when is_atom(attribute_name) do
    attributes = xmlElement(element, :attributes)

    attribute =
      Enum.find(attributes, fn attribute -> xmlAttribute(attribute, :name) == attribute_name end)

    if attribute,
      do: {:ok, normalize_string(xmlAttribute(attribute, :value))},
      else: {:error, :attribute_not_found}
  end

  def normalize_string(charlist) when is_list(charlist), do: to_string(charlist)
  def normalize_string(string) when is_binary(string), do: string
end
