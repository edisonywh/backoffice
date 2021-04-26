defmodule Backoffice.Resolvers.Ecto do
  @moduledoc """
  Resolver for Ecto (currently only works with Postgres)
  """

  @behaviour Backoffice.Resolver

  import Ecto.Query

  def change(resolver_opts, action, %schema{} = resource, attrs \\ %{}) do
    changeset = Keyword.get(resolver_opts, :changeset)[action]

    types = schema.__changeset__
    attrs = cast_attrs(attrs, types)

    case changeset do
      nil ->
        schema
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

  def load(resource, resolver_opts, params) do
    repo = Keyword.fetch!(resolver_opts, :repo)

    preloads = Keyword.get(resolver_opts, :preload, [])
    order_by = Keyword.get(resolver_opts, :order_by, [])

    customize_query =
      Keyword.get(resolver_opts, :query, fn q ->
        q
        |> order_by([q], ^order_by)
        |> preload([q], ^preloads)
      end)

    paginate_opts = %{
      page_size: parse(Map.get(params, "page_size", 20)),
      page_number: parse(Map.get(params, "page", 1))
    }

    resource
    |> customize_query.()
    |> paginate(repo, paginate_opts)
  end

  def search(_mod, resource, resolver_opts, params) do
    params
    |> Enum.map(&Backoffice.Filter.preprocess/1)
    |> List.flatten()
    |> Enum.reduce(resource, fn {_, field, _} = filter, acc ->
      apply_filter(acc, filter, resource.__schema__(:type, field))
    end)
    |> load(resolver_opts, params)
  end

  def get(resource, resolver_opts, params) do
    repo = Keyword.fetch!(resolver_opts, :repo)
    preloads = Keyword.get(resolver_opts, :preload, [])

    case Map.get(params, "id") do
      # If there's no ID, we assume it's a `:new` action.
      nil ->
        resource
        |> struct!()
        |> repo.preload(preloads)

      id ->
        resource
        |> preload([q], ^preloads)
        |> repo.get(id)
    end
  end

  # Attrs comes from form submission, which are all string. We convert them back here.
  defp cast_attrs(attrs, types) do
    types = for {k, v} <- types, into: %{}, do: {to_string(k), v}

    Enum.reduce(attrs, %{}, fn {k, v}, acc ->
      Map.put(acc, k, cast_type(v, types[k]))
    end)
  end

  defp cast_type(attrs, {:assoc, %{related: schema}}) do
    types = schema.__changeset__

    cast_attrs(attrs, types)
  end

  defp cast_type(attr, {:embed, _}) do
    cast_type(attr, :map)
  end

  defp cast_type(attr, :map) when is_binary(attr) do
    case Phoenix.json_library().decode(attr, keys: :atoms) do
      {:error, _} -> attr
      {:ok, value} -> value
    end
  end

  defp cast_type(attr, {:array, type}) do
    attr
    |> String.split(",")
    |> Enum.map(&cast_type(String.trim(&1), type))
  end

  defp cast_type(attr, _type), do: attr

  # Filters

  defp apply_filter(query, {:skip, _field, _value}, _type), do: query

  defp apply_filter(query, {:and, field, {:lt, value}}, _type) do
    query
    |> where([q], field(q, ^field) < ^value)
  end

  defp apply_filter(query, {:and, field, {:lte, value}}, _type) do
    query
    |> where([q], field(q, ^field) <= ^value)
  end

  defp apply_filter(query, {:and, field, {:gt, value}}, _type) do
    query
    |> where([q], field(q, ^field) > ^value)
  end

  defp apply_filter(query, {:and, field, {:gte, value}}, _type) do
    query
    |> where([q], field(q, ^field) >= ^value)
  end

  defp apply_filter(query, {:and, :order_by, {:desc, field}}, _type) do
    query
    |> order_by([q], {:desc, field(q, ^field)})
  end

  defp apply_filter(query, {:and, :order_by, {:asc, field}}, _type) do
    query
    |> order_by([q], {:asc, field(q, ^field)})
  end

  defp apply_filter(query, {:and, field, {:contains, nil}}, _type) do
    query
    |> where([q], is_nil(field(q, ^field)))
  end

  defp apply_filter(query, {:and, field, {:contains, value}}, type)
       when type in [:id, :integer, :boolean] do
    query
    |> where([q], field(q, ^field) == ^value)
  end

  defp apply_filter(query, {:and, field, {:contains, value}}, {_, Ecto.Enum, _}) do
    query
    |> where([q], field(q, ^field) == ^value)
  end

  defp apply_filter(query, {:and, field, {:contains, value}}, _type) do
    value =
      value
      |> String.replace("%", "\%")
      |> String.replace("_", "\_")

    value = "%#{value}%"

    query
    |> where([q], ilike(field(q, ^field), ^value))
  end

  defp apply_filter(query, {:and, field, {:not, nil}}, _type) do
    query
    |> where([q], not is_nil(field(q, ^field)))
  end

  defp apply_filter(query, {:and, field, {:not, value}}, _type) do
    query
    |> where([q], field(q, ^field) != ^value)
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
