defmodule Backoffice.Resolvers.Ecto do
  @moduledoc """
  Resolver for Ecto (currently only works with Postgres)
  """

  @behaviour Backoffice.Resolver

  import Ecto.Query

  # TODO: Review/Tidy up the API, what should they be named and in what position?

  def change(resolver_opts, action, %struct{} = resource, attrs \\ %{}) do
    changeset = Keyword.get(resolver_opts, :changeset)[action]

    case changeset do
      nil ->
        struct
        |> apply(:changeset, [resource, attrs])

      _ ->
        changeset.(resource, attrs)
    end
  end

  def save(resolver_opts, :edit, changeset) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    repo.update(changeset)
  end

  def save(resolver_opts, :new, changeset) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    repo.insert(changeset)
  end

  def load(resource, resolver_opts, page_opts) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    preloads = Keyword.get(resolver_opts, :preload, [])
    page = Map.get(page_opts, "page")

    resource
    |> preload([q], ^preloads)
    |> repo.paginate(%{page: page})
  end

  def search(_mod, resource, resolver_opts, page_opts) do
    page_opts
    |> Enum.map(&Backoffice.Filter.preprocess/1)
    |> List.flatten()
    |> Enum.reduce(resource, fn {_, field, _} = filter, acc ->
      Backoffice.Filter.apply_filter(acc, filter, resource.__schema__(:type, field))
    end)
    |> load(resolver_opts, page_opts)
  end

  def get(resource, resolver_opts, page_opts) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    preloads = Keyword.get(resolver_opts, :preload, [])

    id = Map.get(page_opts, "id")

    resource
    |> preload([q], ^preloads)
    |> repo.get(id)
  end
end
