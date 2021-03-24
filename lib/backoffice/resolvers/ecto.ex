defmodule Backoffice.Resolvers.Ecto do
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

    # TODO: Optimize and select only shown resources (this means adding the original module here so we can access __MODULE__.fields())

    resource
    |> ordering()
    |> preload([q], ^preloads)
    |> repo.paginate(%{page: page})
  end

  def get(resource, resolver_opts, page_opts) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    preloads = Keyword.get(resolver_opts, :preload, [])

    id = Map.get(page_opts, "id")

    resource
    |> preload([q], ^preloads)
    |> repo.get(id)
  end

  # TODO: Let user click on fields to do ordering?
  def ordering(resource) do
    [field | _] = Backoffice.Resources.resolve_schema(resource).__schema__(:primary_key)

    resource
    |> order_by([q], {:desc, field(q, ^field)})
  end

  def do_filter(query, "", _), do: query
  def do_filter(query, nil, _), do: query
  def do_filter(query, _search, []), do: query

  def do_filter(query, search, [field | rest]) do
    query
    |> or_where([q], ilike(field(q, ^field), ^"%#{search}%"))
    |> do_filter(search, rest)
  end

  def search(mod, resource, resolver_opts, page_opts) do
    fields = mod.search_fields()
    search = Map.get(page_opts, "search")

    resource
    |> do_filter(search, fields)
    |> load(resolver_opts, page_opts)
  end
end
