defmodule Mnesia.Ecto do

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Storage

  @doc """
  Define new Mnesia table.

  See available options for table definition to be passed via `:tab_def` at
  http://www.erlang.org/doc/man/mnesia.html#create_table-2.
  """
  @spec storage_up([{:name, atom}]) ::
    :ok | {:error, :already_up} | {:error, term}
  @spec storage_up([{:name, atom}, {:tab_def, Keyword.t}]) ::
    :ok | {:error, :already_up} | {:error, term}
  def storage_up name: name do
    storage_up name: name, tab_def: []
  end
  def storage_up name: name, tab_def: tab_def do
    :mnesia.create_schema [node]
    case :mnesia.create_table name, tab_def do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, ^name}} -> {:error, :already_up}
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete Mnesia table.
  """
  @spec storage_down([{:name, atom}]) :: :ok | {:error, :already_down} |
    {:error, term}
  def storage_down name: name do
    case :mnesia.delete_table name do
      {:atomic, :ok} -> :ok
      {:aborted, {:no_exists, ^name}} -> {:error, :already_down}
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    :ok
  end

  @doc """
  Deletes a sigle model with the given filters.
  """
  def delete(_repo, %{source: {_prefix, table}}, filters, _auto_id, _opts) do
    tbl = String.to_atom(table)
    :mnesia.dirty_select(tbl, match_spec(tbl, filters))
    |> case do
      [] -> {:error, :stale}
      [row] ->
        :ok = :mnesia.dirty_delete_object row
        {:ok, to_keyword(row)}
    end
  end

  @doc """
  Convert filters keyword into Erlang match specification for Mnesia table.

  Matching result would return the whole objects.
  """
  @spec match_spec(atom, Keyword.t) :: [{tuple, [], [:'$_']}]
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
end
