defmodule Mix.Tasks.Dialyzer do
  @moduledoc ~S"""
  Run Dialyzer against project.

  Dialyzer is an optional Erlang package and must be installed for the task to
  work.

  Required preparation for first launch:

      dialyzer --build_plt ~/.exenv/versions/1.1.1/lib/elixir/ebin/ \ 
        _build/dev/lib/ecto/ebin/ --apps erts kernel stdlib mnesia

  where paths for Elixir apps' `ebin` folder could be obtained with:

      iex> :code.lib_dir :phoenix
      iex> :code.lib_dir :ecto

  After version updates PLT may require rebuilding from scratch after removal
  of `~/.dialyzer_plt`. New apps may be added using `--add_to_plt` option. See
  more details at
  http://www.erlang.org/doc/apps/dialyzer/dialyzer_chapter.html.
  """
  use Mix.Task

  def run _ do
    Mix.Task.run "compile"
    path = Mix.Project.compile_path
    {output, _} = System.cmd("dialyzer", [path], stderr_to_stdout: true)
    IO.puts output
  end
end
