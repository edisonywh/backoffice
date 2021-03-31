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
    # TODO: Check if user has toggled `edit` to be true
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

    paginate_opts = %{
      page_size: parse(Map.get(page_opts, "page_size", 20)),
      page_number: parse(Map.get(page_opts, "page", 1))
    }

    resource
    |> preload([q], ^preloads)
    |> paginate(repo, paginate_opts)
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

  # Pagination, code adapted from `Scrivener.Ecto`
  # This is because we don't want to force users to add Scrivener.Ecto to the rest of the application just for Backoffice.
  @spec paginate(Ecto.Query.t(), atom(), map()) :: Backoffice.Page.t()
  defp paginate(query, repo, %{
         page_size: page_size,
         page_number: page_number
       }) do
    total_entries = total_entries(query, repo)
    total_pages = total_pages(total_entries, page_size)

    page_number = min(total_pages, page_number)

    %Backoffice.Page{
      entries: entries(query, repo, page_number, total_pages, page_size),
      page_number: page_number,
      page_size: page_size,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  defp entries(_, _, page_number, total_pages, _) when page_number > total_pages, do: []

  defp entries(query, repo, page_number, _, page_size) do
    offset = page_size * (page_number - 1)

    query
    |> offset(^offset)
    |> limit(^page_size)
    |> all(repo)
  end

  defp total_entries(query, repo) do
    total_entries =
      query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> aggregate()
      |> one(repo)

    total_entries || 0
  end

  defp aggregate(%{distinct: %{expr: expr}} = query) when expr == true or is_list(expr) do
    query
    |> exclude(:select)
    |> count()
  end

  defp aggregate(
         %{
           group_bys: [
             %Ecto.Query.QueryExpr{
               expr: [
                 {{:., [], [{:&, [], [source_index]}, field]}, [], []} | _
               ]
             }
             | _
           ]
         } = query
       ) do
    query
    |> exclude(:select)
    |> select([{x, source_index}], struct(x, ^[field]))
    |> count()
  end

  defp aggregate(query) do
    query
    |> exclude(:select)
    |> select(count("*"))
  end

  defp count(query) do
    query
    |> subquery
    |> select(count("*"))
  end

  defp total_pages(0, _), do: 1

  defp total_pages(total_entries, page_size) do
    (total_entries / page_size) |> Float.ceil() |> round
  end

  defp all(query, repo) do
    repo.all(query)
  end

  defp one(query, repo) do
    repo.one(query)
  end

  defp parse(string) when is_binary(string) do
    string
    |> Integer.parse()
    |> elem(0)
  end

  defp parse(term), do: term
end
