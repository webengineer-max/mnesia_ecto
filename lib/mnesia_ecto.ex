defmodule Mnesia.Ecto do
  @moduledoc """
  Mnesia adapter for Ecto.
  """

  alias Ecto.Migration.Index
  alias Ecto.Migration.Table
  alias Mnesia.Ecto.Query, as: MnesiaQuery

  @behaviour Ecto.Adapter.Storage

  @doc false
  def storage_up(_) do
    :mnesia.stop
    :mnesia.create_schema([node])
    :mnesia.start
  end

  @doc false
  def storage_down(_) do
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
    :stopped = :mnesia.stop
    :ok
  end

  @doc false
  def embed_id(nil), do: Ecto.UUID.generate
  def embed_id(id), do: id

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
  def prepare(:all, %{from: {table, _}, select: %{expr: fields},
              wheres: wheres}) do
    {:cache, {:all, MnesiaQuery.match_spec(table, fields: fields,
              wheres: wheres)}}
  end

  def prepare(:delete_all, %{from: {table, _}, select: nil, wheres: wheres}) do
    {:cache, {:delete_all, MnesiaQuery.match_spec(table, wheres: wheres)}}
  end

  @doc false
  def execute(_, %{select: %{expr: expr}, sources: {{table, model}}},
              {:all, [{match_head, guards, result}]}, params, _, _) do
    spec = [{match_head, MnesiaQuery.resolve_params(guards, params), result}]
    rows = table |> String.to_atom |> :mnesia.dirty_select(spec)
    if expr == {:&, [], [0]} do
      rows = rows |> Enum.map(fn [record] ->
        [MnesiaQuery.record2model(record, model)]
      end)
    end
    {length(rows), rows}
  end

  def execute(_, %{sources: {{table, _}}},
              {:delete_all, [{_, [{:==, :"$1", {:^, [], [0]}}], _}]}, params,
              _, _) do
    table_atom = table |> String.to_atom
    deleted = params |> Enum.map(&:mnesia.dirty_delete(table_atom, &1))
      |> Enum.count
    {deleted, nil}
  end

  def execute(_, %{sources: {{table, _}}},
              {:delete_all, [{match_head, guards, result}]}, params, _, _) do
    spec = [{match_head, MnesiaQuery.resolve_params(guards, params), result}]
    table_atom = table |> String.to_atom
    deleted = table_atom |> :mnesia.dirty_select(spec)
      |> Enum.map(&:mnesia.dirty_delete(table_atom, &1)) |> Enum.count
    {deleted, nil}
  end

  @doc false
  def update(_, %{source: {_, table}}, fields, filters, _, _, _) do
    do_update = fn ->
      table |> String.to_atom
      |> :mnesia.select(MnesiaQuery.match_spec(table, filters: filters))
      |> case do
        [] -> {:error, :stale}
        [record] ->
          row = record |> MnesiaQuery.record2keyword |> Dict.merge(fields)
            |> MnesiaQuery.keyword2record(table)
          :ok = :mnesia.write(row)
          {:ok, MnesiaQuery.record2keyword(row)}
      end
    end
    {:atomic, result} = do_update |> :mnesia.transaction
    result
  end

  @doc false
  def insert(_, _, _, {_, :id, _}, _, _) do
    raise "only :binary_id type supported for autogenerate_id"
  end

  def insert(repo, meta, fields, {field, :binary_id, value}, [], opts) do
    with_id = Keyword.put(fields, field, embed_id(value))
    insert(repo, meta, with_id, nil, [], opts)
  end

  def insert(_, %{source: {_, table}}, fields, nil, _, _) do
    row = MnesiaQuery.keyword2record(fields, table)
    table_atom = table |> String.to_atom
    key = table_atom |> :mnesia.table_info(:attributes) |> Enum.at(1)
    match_head = table_atom |> :mnesia.table_info(:wild_pattern)
      |> put_elem(1, elem(row, 1))
    do_insert = fn ->
      table_atom |> :mnesia.select([{match_head, [], [:taken]}])
      |> case do
        [:taken] -> {:invalid, [{key, "has already been taken"}]}
        [] ->
          :ok = :mnesia.write(row)
          {:ok, MnesiaQuery.record2keyword(row)}
      end
    end
    {:atomic, result} = do_insert |> :mnesia.transaction
    result
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

  defp disc_copies do
    case :mnesia.system_info(:use_dir) do
      true -> [node]
      false -> []
    end
  end

  @doc false
  def execute_ddl(repo,
                  {:create_if_not_exists, %Table{name: name} = table, columns},
                  opts) do
    unless name in :mnesia.system_info(:tables) do
      execute_ddl(repo, {:create, table, columns}, opts)
    end
  end

  def execute_ddl(_, {:create, %Table{name: name}, columns}, _) do
    fields = for {:add, field, _, _} <- columns, do: field
    {:atomic, :ok} = :mnesia.create_table(name, attributes: fields,
                                          disc_copies: disc_copies)
    :ok
  end

  def execute_ddl(_, {:create, %Index{table: table, columns: columns}}, _) do
    for attr <- columns do
      {:atomic, :ok} = :mnesia.add_table_index(table, attr)
    end
    :ok
  end

  def execute_ddl(_, {:drop, %Table{name: name}}, _) do
    {:atomic, :ok} = :mnesia.delete_table(name)
    :ok
  end

  def execute_ddl(_, {:drop_if_exists, %Table{name: name}}, _) do
    if :tables |> :mnesia.system_info |> Enum.member?(name) do
      {:atomic, :ok} = :mnesia.delete_table(name)
    end
    :ok
  end

  def execute_ddl(_, {:drop, %Index{table: table, columns: columns}}, _) do
    for attr <- columns do
      {:atomic, :ok} = :mnesia.del_table_index(table, attr)
    end
    :ok
  end

  def execute_ddl(_, {:drop_if_exists, %Index{table: table, columns: columns}}, _) do
    attrs = table |> :mnesia.table_info(:attributes)
    indexes = table |> :mnesia.table_info(:index) |> Enum.map(&(&1 - 2))
      |> Enum.map(&Enum.fetch(attrs, &1))
    for attr <- columns, attr in indexes do
      {:atomic, :ok} = :mnesia.del_table_index(table, attr)
    end
    :ok
  end

  @doc false
  def supports_ddl_transaction?, do: false
end
