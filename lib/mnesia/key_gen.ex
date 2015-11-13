defmodule Mnesia.KeyGen do
  @moduledoc """
  Generate values for database keys.
  """

  @doc """
  Issue new unique slug.

  Uniqueness is ensured by querying DB for existing values.

  There is no guarantee for slug uniqueness through time. I.e. slug may be
  reused after deletion.
  """
  def slug(phrase, table, attribute \\ :key)

  def slug(phrase, table, attribute) when is_binary(table) do
    slug(phrase, String.to_atom(table), attribute)
  end

  def slug(phrase, table, attribute) do
    condensed = phrase |> String.downcase
      |> String.replace(~r/[^a-z0-9]+/, "-") |> String.strip(?-)
    wild = table |> :mnesia.table_info(:wild_pattern)
    # Attribute position in table record.
    position =
      case attribute do
        :key -> 1
        _ -> table |> :mnesia.table_info(:attributes)
          |> Enum.find_index(&(&1==attribute))
      end
    make_unique(condensed, wild, position)
  end

  defp make_unique(slug, wild, position, iteration \\ 1) do
    random = slug |> randomize(iteration)
    match_head = wild |> put_elem(position, random)
    match_spec = [{match_head, [], [:exists]}]
    table = wild |> elem(0)
    case :mnesia.dirty_select(table, match_spec) do
      [] -> random
      [:exists] -> make_unique(slug, wild, position, iteration+1)
    end
  end

  defp randomize(slug, iteration) do
    suffix = 10 |> :math.pow(iteration) |> round |> :rand.uniform |> to_string
    slug <> "-" <> suffix
  end

end
