defmodule Mnesia.Ecto.Query do
  @moduledoc """
  Translate between Ecto and Mnesia query languages.
  """

  alias Ecto.Query.QueryExpr

  @doc """
  Return match specification for Mnesia table.

  List with specified fields only will be returned in matching result. Without
  the fields argument the whole objects would be returned.
  """
  # TODO Refactor this clause to another name probably as returning whole
  # objects. Update the @doc.
  def match_spec(table, filters) do
    [{to_record(filters, table, :_), [], [:'$_']}]
  end

  def match_spec(table, [], fields: :all) do
    all_fields = table |> String.to_atom |> :mnesia.table_info(:attributes)
    match_spec(table, [], fields: all_fields)
  end

  def match_spec(table, [], fields: fields) do
    result = table |> placeholder4field |> Dict.take(fields)
    [{match_head(table), [], [result]}]
  end

  def match_spec(table, fields, wheres: wheres) do
    [{match_head(table), wheres2guards(wheres, table), [result(fields, table)]}]
  end

  def match_head(table) do
    table
    |> placeholder4field
    |> Dict.values
    |> Enum.into([String.to_atom(table)])
    |> List.to_tuple
  end

  @doc """
  Replace AST of `wheres` parameters with values on `execute` stage.
  """
  def resolve_params(guards, params) do resolve_params(guards, params, []) end
  def resolve_params([{operator, placeholder, {:^, [], [index]}} | t], params, acc) do
    resolve_params(t, params, [{operator, placeholder, Enum.at(params, index)} | acc])
  end
  def resolve_params([], params, acc) do acc end

  @doc """
  Convert Ecto `wheres` into Mnesia match spec guards.
  """
  def wheres2guards(wheres, table) do wheres2guards(wheres, table, []) end
  defp wheres2guards([%QueryExpr{expr: {operator, [], [field, parameter]}} | t], table, acc) do
    guard = {operator, field2placeholder(field, table), parameter}
    wheres2guards(t, table, [guard | acc])
  end
  defp wheres2guards([], table, acc) do acc end

  @doc """
  Return Mnesia match spec placeholder for field AST.
  """
  def field2placeholder({{:., [], [{:&, [], [0]}, name]}, _, []}, table) do
    table |> placeholder4field |> Dict.get(name)
  end

  @doc """
  Map table fields to placeholders formatted like :'&1', :'&2', ... .
  """
  @spec placeholder4field(String.t) :: Keyword.t
  def placeholder4field(table) do
    all_fields = table |> String.to_atom |> :mnesia.table_info(:attributes)
    placeholders =
      1..length(all_fields)
      |> Enum.map(&"$#{&1}")
      |> Enum.map(&String.to_atom/1)
    all_fields |> Enum.zip(placeholders)
  end

  def result({:&, [], [0]}, table) do
    table |> placeholder4field |> Dict.values
  end

  def result(ast = {{:., [], [{:&, [], [0]}, field]}, _, _}, table) do
    result([ast], table)
  end

  def result([{{:., [], [{:&, [], [0]}, field]}, _, _} | t], table) do
    result(t, table, [field])
  end

  defp result([{{:., [], [{:&, [], [0]}, field]}, _, _} | t], table, acc) do
    result(t, table, [field | acc])
  end

  defp result([], table, acc) do
    placeholders = placeholder4field(table)
    acc |> Enum.map(&Dict.get(placeholders, &1))
  end

  @doc """
  Convert Keyword into table record.

  Populate missed fields with default value.
  """
  def to_record(keyword, table, default \\ nil) do
    name_atom = String.to_atom(table)
    name_atom
    |> :mnesia.table_info(:attributes)
    |> Enum.map(&Keyword.get(keyword, &1, default))
    |> Enum.into([name_atom])
    |> List.to_tuple
  end

  @doc """
  Convert Mnesia record object into Keyword.
  """
  def to_keyword(record) do
    [table | values] = Tuple.to_list(record)
    :mnesia.table_info(table, :attributes)
    |> Enum.zip(values)
  end

  def row2model(row, model) do
    map = Enum.zip(model.__schema__(:fields), row) |> Enum.into(%{})
    [Map.merge(model.__struct__, map)]
  end
end
