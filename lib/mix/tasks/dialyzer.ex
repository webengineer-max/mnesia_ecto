defmodule Mix.Tasks.Dialyzer do
  use Mix.Task

  def run _ do
    Mix.Task.run "compile"
    path = Mix.Project.compile_path
    {output, _} = System.cmd("dialyzer", [path], stderr_to_stdout: true)
    IO.puts output
  end
end
