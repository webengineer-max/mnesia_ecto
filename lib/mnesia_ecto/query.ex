defmodule Mnesia.Ecto.Query do
  @moduledoc """
  Translate between Ecto and Mnesia query languages.
  """

  @doc """
  Return match specification for Mnesia table.

  List with specified fields only will be returned in matching result. Without
  the fields argument the whole objects would be returned.
  """
  # TODO Refactor this clause to another name probably as the one returning
  # whole objects. Update the @doc.
  def match_spec(table, filters: filters) do
    [{keyword2record(filters, table, :_), [], [:'$_']}]
  end

  def match_spec(table, fields: fields, wheres: wheres) do
    [{match_head(table), wheres2guards(wheres, table), [result(fields, table)]}]
  end

  def match_spec(table, wheres: wheres) do
    [{match_head(table), wheres2guards(wheres, table), [:'$1']}]
  end

  defp match_head(table) do
    table
    |> placeholder4field
    |> Dict.values
    |> Enum.into([String.to_atom(table)])
    |> List.to_tuple
  end

  @doc """
  Replace AST of `wheres` with parameters.
  """
  def resolve_params(guards, params) do
    resolve_params(guards, params, [])
  end

  defp resolve_params(
      [{operator, placeholder, {:^, [], [index]}} | t], params, acc) do
    resolve_params(
      t, params, [{operator, placeholder, Enum.at(params, index)} | acc])
  end

  defp resolve_params([{operator, placeholder, val} | t], params, acc) do
    resolve_params(t, params, [{operator, placeholder, val} | acc])
  end

  defp resolve_params([], _, acc) do
    acc
  end

  @doc """
  Convert Ecto `wheres` into Mnesia match spec guards.
  """
  def wheres2guards(wheres, table) do wheres2guards(wheres, table, []) end
  defp wheres2guards([%{expr: {operator, [], [field, parameter]}} | t], table,
                     acc) do
    guard = {operator, field2placeholder(field, table), parameter}
    wheres2guards(t, table, [guard | acc])
  end
  defp wheres2guards([], _, acc) do acc end

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

  @doc """
  Format result for Mnesia match spec according to queried fields.
  """
  def result(nil, _) do
    [nil]
  end

  def result({:&, [], [0]}, _) do
    [:'$_'] # TODO For record2model in execute.
  end

  def result({{:., [], [{:&, [], [0]}, _]}, _, _} = ast, table) do
    result([ast], table)
  end

  def result([{{:., [], [{:&, [], [0]}, field]}, _, _} | t], table) do
    result(t, table, [field])
  end

  def result(val, _) do
    [val]
  end

  defp result([{{:., [], [{:&, [], [0]}, field]}, _, _} | t], table, acc) do
    result(t, table, [field | acc])
  end

  defp result([], table, acc) do
    placeholders = placeholder4field(table)
    acc |> Enum.reverse |> Enum.map(&Dict.get(placeholders, &1))
  end

  @doc """
  Return placeholers in select result to be used for ordering.
  """
  def order_bys2placeholders([], _), do: []
  def order_bys2placeholders(order_bys, table), do: order_bys2placeholders(order_bys, table, [])
  def order_bys2placeholders([%{expr: [asc: {{:., [], [{:&, [], [0]}, field]}, _,
          _}]} | t], table, acc) do
    placeholder = table |> placeholder4field |> Dict.get(field)
    order_bys2placeholders(t, table, [placeholder | acc])
  end
  def order_bys2placeholders([], _, acc), do: acc |> Enum.reverse

  @doc """
  Order selected rows according to placeholders position in result.
  """
  def reorder(rows, [], _), do: rows
  def reorder(rows, [order_by], [result_placeholders]) do
    position = result_placeholders |> Enum.find_index(&(&1==order_by))
    rows |> Enum.sort_by(&Enum.at(&1, position))
  end

  @doc """
  Convert Keyword into table record.

  Populate missed fields with default value.
  """
  def keyword2record(keyword, table, default \\ nil) do
    name_atom = String.to_atom(table)
    name_atom
    |> :mnesia.table_info(:attributes)
    |> Enum.map(&Keyword.get(keyword, &1, default))
    |> Enum.into([name_atom])
    |> List.to_tuple
  end

  @doc """
  Convert Mnesia record object into Ecto Model.
  """
  def record2model(record, model) do
    map =
      record
      |> record2keyword
      |> Enum.into(%{})
    Map.merge(model.__struct__, map)
  end

  @doc """
  Convert Mnesia record object into Keyword.
  """
  def record2keyword(record) do
    [table | values] = Tuple.to_list(record)
    table |> :mnesia.table_info(:attributes) |> Enum.zip(values)
  end

end
