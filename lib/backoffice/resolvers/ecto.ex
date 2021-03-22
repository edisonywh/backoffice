defmodule Backoffice.Resolvers.Ecto do
  @behaviour Backoffice.Resolver

  import Ecto.Query

  # TODO: Review/Tidy up the API, what should they be named and in what position?

  def change(resolver_opts, %struct{} = resource, attrs \\ %{}) do
    changeset = Keyword.get(resolver_opts, :changeset)[:edit]

    case changeset do
      nil ->
        struct
        |> apply(:changeset, [resource, attrs])

      _ ->
        changeset.(resource, attrs)
    end
  end

  def save(resolver_opts, changeset) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    # TODO: Check action to determine if it's :insert or :update
    repo.update(changeset)
  end

  def load(resource, resolver_opts, page_opts) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    page = Map.get(page_opts, "page")

    # TODO: Optimize and select only shown resources (this means adding the original module here so we can access fields)

    resource
    |> ordering()
    |> repo.paginate(%{page: page})
  end

  def get(resource, resolver_opts, page_opts) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    id = Map.get(page_opts, "id")

    repo.get(resource, id)
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
