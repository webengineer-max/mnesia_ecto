defmodule Mnesia.Ecto.Utils do
  @moduledoc """
  Useful tools shared among projects.
  """

  @doc """
  Model callback to update changeset with unique slug.

  Intended for `before_insert` lifetyme calback. `dst_field` will be populated
  with a slug derived from `src_field`.
  """
  def slugify(changeset, src_field, dst_field) do
    table = :source |> changeset.model.__struct__.__schema__ |> String.to_atom
    slug = changeset.changes[src_field] |> Mnesia.KeyGen.slug(table, dst_field)
    %{changeset | changes: Map.put(changeset.changes, dst_field, slug)}
  end

end
