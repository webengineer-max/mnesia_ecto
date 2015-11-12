Logger.configure(level: :info)

ExUnit.start

Application.put_env(:ecto, :primary_key_type, :binary_id)

Code.require_file "../deps/ecto/integration_test/support/repo.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/models.exs", __DIR__
Code.require_file "../deps/ecto/integration_test/support/migration.exs", __DIR__

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup do
    :tables |> :mnesia.system_info
      |> Enum.filter(&(&1 != :schema and &1 != :schema_migrations))
      |> Enum.map(&:mnesia.clear_table/1)
    :ok
  end
end

alias Ecto.Integration.TestRepo

Application.put_env(:ecto, TestRepo, adapter: Mnesia.Ecto)
Application.put_env(:mnesia, :schema_location, :ram)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto
end

# Load up the repository, start it, and run migrations
_   = Ecto.Storage.down(TestRepo)
:ok = Ecto.Storage.up(TestRepo)

{:ok, _pid} = TestRepo.start_link

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
