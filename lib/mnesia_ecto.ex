defmodule Mnesia.Ecto do
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
end
