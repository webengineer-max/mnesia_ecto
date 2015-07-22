defmodule Mnesia.EctoTest do
  use ExUnit.Case

  import Mnesia.Ecto

  @table_name :test

  test "create Mnesia table" do
    assert :ok = storage_up name: @table_name
    assert {:error, :already_up} = storage_up name: @table_name
    bad_def = [name: :foo, tab_def: [foo: :bar]]
    assert {:error, {:badarg, :foo, :foo}} = storage_up bad_def
  end

  test "delete Mnesia table" do
    storage_up name: @table_name
    assert :ok = storage_down name: @table_name
  end
end
