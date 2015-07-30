defmodule Mix.Tasks.Dialyzer do
  use Mix.Task

  def run _ do
    Mix.Task.run "compile"
    {output, _} = System.cmd "dialyzer", [Mix.Project.compile_path],
      stderr_to_stdout: true
    IO.puts output
  end
end
