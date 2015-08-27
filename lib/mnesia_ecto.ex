defmodule Mnesia.Ecto do

  alias Ecto.Migration.Table

  @behaviour Ecto.Adapter.Storage

  @doc false
  def storage_up _opts do
    :mnesia.create_schema [node]
    :mnesia.start
  end

  @doc false
  def storage_down _opts do
    :mnesia.stop
    :mnesia.delete_schema [node]
  end

  @behaviour Ecto.Adapter

  @doc false
  defmacro __before_compile__(_env) do
    :ok
  end

  @doc false
  def delete(_repo, %{source: {_prefix, table}}, filters, _auto_id, _opts) do
    tbl = String.to_atom(table)
    :mnesia.dirty_select(tbl, match_spec(tbl, filters))
    |> case do
      [] -> {:error, :stale}
      [row] ->
        :ok = :mnesia.dirty_delete_object row
        {:ok, to_keyword row}
    end
  end

  @doc """
  Convert filters keyword into Erlang match specification for Mnesia table.

  Matching result would return the whole objects.
  """
  def match_spec table, filters do
    [{match_head(table, filters), [], [:'$_']}]
  end

  defp match_head table, filters do
    :mnesia.table_info(table, :attributes)
    |> Enum.map(&Keyword.get(filters, &1, :_))
    |> Enum.into([table])
    |> List.to_tuple
  end

  @doc """
  Convert Mnesia record object into Keyword.
  """
  def to_keyword record do
    [table | values] = Tuple.to_list record
    :mnesia.table_info(table, :attributes)
    |> Enum.zip(values)
  end

  @doc false
  def start_link _repo, _opts do
    {:ok, []} = Application.ensure_all_started :mnesia_ecto
    {:ok, self}   # XXX despite spec allows just :ok, test fails without PID
  end

  @behaviour Ecto.Adapter.Migration

  @doc false
  def execute_ddl _repo, {:create, %Table{name: name}, columns}, _opts do
    fields = for {:add, field, _type, _col_opts} <- columns do
      field
    end
    {:atomic, :ok} = :mnesia.create_table name, [attributes: fields]
    :ok
  end

  def supports_ddl_transaction?, do: false
end
