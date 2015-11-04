defmodule Mnesia.Ecto do
  @moduledoc """
  Mnesia adapter for Ecto.
  """

  alias Ecto.Migration.Index
  alias Ecto.Migration.Table
  alias Mnesia.Ecto.Query, as: MnesiaQuery

  @behaviour Ecto.Adapter.Storage

  @doc false
  def storage_up(_opts) do
    :mnesia.stop
    :mnesia.create_schema([node])
    :mnesia.start
  end

  @doc false
  def storage_down(_opts) do
    :mnesia.stop
    :mnesia.delete_schema([node])
  end

  @behaviour Ecto.Adapter

  @doc false
  defmacro __before_compile__(_env), do: :ok

  @doc false
  def start_link(_, _) do
    {:ok, _} = Application.ensure_all_started(:mnesia_ecto)
    {:ok, self}
  end

  @doc false
  def stop(_, _) do
    :mnesia.stop
    :ok
  end

  @doc false
  def embed_id(_), do: Ecto.UUID.generate

  @doc false
  def dump(_, %{__struct__: _} = struct), do: {:ok, struct}
  def dump(_, map) when is_map(map) do
    map =
      map
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into %{}
    {:ok, map}
  end
  def dump(_, value), do: {:ok, value}

  @doc false
  def load(_, value), do: {:ok, value}

  @doc false
  def prepare(:all, %{from: {table, _}, select: %{expr: fields}, wheres: wheres}) do
    {:cache, {:all, MnesiaQuery.match_spec(table, fields: fields, wheres: wheres)}}
  end

  def prepare(:delete_all, %{from: {table, _}, wheres: []}) do
    {:cache, {:delete_all, fn ->
      name_atom = table |> String.to_atom
      size = :mnesia.table_info(name_atom, :size)
      {:atomic, :ok} = :mnesia.clear_table(name_atom)
      {size, nil}
    end}}
  end

  def prepare(:delete_all, %{from: {table, _}, wheres: wheres}) do
    {:cache, {:delete_all, fn ->
      spec = MnesiaQuery.match_spec(table, wheres: wheres)
      {_, size} =
        table
        |> String.to_atom
        |> :mnesia.dirty_select(spec)
        |> Enum.map_reduce(0, fn id, acc ->
          {:mnesia.delete({table |> String.to_atom, id}), acc+1}
        end)
      {size, nil}
    end}}
  end

  @doc false
  def execute(_, %{select: %{expr: expr}, sources: {{table, model}}}, {:all, [{match_head, guards, result}]}, params, _, _) do
    spec = [{match_head, MnesiaQuery.resolve_params(guards, params), result}]
    rows = table |> String.to_atom |> :mnesia.dirty_select(spec)
    if expr == {:&, [], [0]} do
      rows = rows |> Enum.map(fn [record] ->
        [MnesiaQuery.record2model(record, model)]
      end)
    end
    {length(rows), rows}
  end

  def execute(_, _, {:delete_all, fun}, _, nil, _) do
    fun.()
  end

  @doc false
  def update(_, %{source: {_, table}} = meta, fields, filters, _, _, _) do
    table
    |> String.to_atom
    |> :mnesia.dirty_select(MnesiaQuery.match_spec(table, filters: filters))
    |> case do
      [] -> {:error, :stale}
      [record] ->
        to_insert = record |> MnesiaQuery.record2keyword |> Dict.merge(fields)
        insert(nil, meta, to_insert, nil, nil, nil)
    end
  end

  @doc false
  def insert(_, _, _, {_, :id, _}, _, _) do
    raise "only :binary_id type supported for autogenerate_id"
  end

  def insert(repo, meta, fields, {field, :binary_id, _}, [], opts) do
    with_id = Keyword.put(fields, field, embed_id(nil))
    insert(repo, meta, with_id, nil, [], opts)
  end

  def insert(_, %{source: {_, table}}, fields, nil, _, _) do
    row = MnesiaQuery.keyword2record(fields, table)
    :ok = :mnesia.dirty_write(row)
    {:ok, MnesiaQuery.record2keyword(row)}
  end

  @doc false
  def delete(_, %{source: {_, table}}, filters, _, _) do
    table
    |> String.to_atom
    |> :mnesia.dirty_select(MnesiaQuery.match_spec(table, filters: filters))
    |> case do
      [] -> {:error, :stale}
      [row] ->
        :ok = :mnesia.dirty_delete_object(row)
        {:ok, MnesiaQuery.record2keyword(row)}
    end
  end

  @behaviour Ecto.Adapter.Migration

  @doc false
  def execute_ddl(repo,
                  {:create_if_not_exists, table=%Table{name: name}, columns},
                  opts) do
    unless name in :mnesia.system_info(:tables) do
      execute_ddl(repo, {:create, table, columns}, opts)
    end
  end

  def execute_ddl(_, {:create, %Table{name: name}, columns}, _) do
    fields = for {:add, field, _, _} <- columns do
      field
    end
    {:atomic, :ok} = :mnesia.create_table(name, attributes: fields)
    :ok
  end

  def execute_ddl(_, {:create, %Index{columns: columns, table: table}}, _) do
    for attr <- columns do
      {:atomic, :ok} = :mnesia.add_table_index(table, attr)
    end
  end

  @doc false
  def supports_ddl_transaction?, do: false
end
