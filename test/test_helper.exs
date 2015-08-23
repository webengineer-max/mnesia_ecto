Logger.configure(level: :info)

ExUnit.start

Application.put_env(:ecto, :primary_key_type, :binary_id)

Code.require_file "../deps/ecto/integration_test/support/repo.exs", __DIR__

defmodule Ecto.Integration.Case do
  use ExUnit.CaseTemplate

  setup_all do
    # Run with schema in RAM to avoid clashing with server
    :mnesia.start
  end
end

alias Ecto.Integration.TestRepo

Application.put_env(:ecto, TestRepo,
                    adapter: Mnesia.Ecto)

defmodule Ecto.Integration.TestRepo do
  use Ecto.Integration.Repo, otp_app: :ecto
end

# Load up the repository, start it, and run migrations
_   = Ecto.Storage.down(TestRepo)
:ok = Ecto.Storage.up(TestRepo)

{:ok, _pid} = TestRepo.start_link

:ok = Ecto.Migrator.up(TestRepo, 0, Ecto.Integration.Migration, log: false)
