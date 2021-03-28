defmodule Backoffice.Resolvers.Ecto do
  @moduledoc """
  Resolver for Ecto (currently only works with Postgres)

  Ships with a filtering engine that translates query params into Ecto filters.

  Examples:

    /admin/users?name=waldo # => substring search
    /admin/users?id=1 # => integer equality search
    /admin/users?verified=true # => boolean search
    /admin/users?id=[gte]60 # => integer greater than N (opts: :gte, :gt, :lte, :lt)
    /admin/users?order_by=[desc]id # => order_by (opts: :desc, :asc)
    /admin/users?inserted_at[from]=2020-12-30&inserted_at[to]=2020-12-31 # => datetime search
    /admin/users?processed_at=nil # nil
    /admin/users?processed_at=[not]nil # not nil
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
    |> Enum.map(&preprocess/1)
    |> List.flatten()
    |> Enum.reduce(resource, fn {_, field, _} = filter, acc ->
      do_filter(acc, filter, resource.__schema__(:type, field))
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

  defp preprocess({"page", value}) do
    {:skip, :page, value}
  end

  defp preprocess({field, <<"[gte]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:gte, String.to_integer(value)}}
  end

  defp preprocess({field, <<"[gt]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:gt, String.to_integer(value)}}
  end

  defp preprocess({field, <<"[lte]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:lte, String.to_integer(value)}}
  end

  defp preprocess({field, <<"[lt]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:lt, String.to_integer(value)}}
  end

  defp preprocess({field, <<"[not]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:not, maybe_nil(value)}}
  end

  defp preprocess({field, <<"[desc]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:desc, String.to_existing_atom(value)}}
  end

  defp preprocess({field, <<"[asc]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:asc, String.to_existing_atom(value)}}
  end

  defp preprocess({field, value}) when is_binary(value) do
    {:and, String.to_existing_atom(field), {:contains, maybe_nil(value)}}
  end

  # If it is a query for datetime with `from` & `to` field, we convert it to
  # a `gt` from and a `lt` to, since that's what the Ecto query looks like.
  defp preprocess({field, value}) when is_map(value) do
    preprocess_date(field, value)
  end

  defp preprocess_date(field, %{"from" => from, "to" => to}) do
    [
      {:and, String.to_existing_atom(field), {:gt, to_naive_datetime(from)}},
      {:and, String.to_existing_atom(field), {:lt, to_naive_datetime(to)}}
    ]
  end

  defp preprocess_date(field, %{"from" => from}) do
    {:and, String.to_existing_atom(field), {:gt, to_naive_datetime(from)}}
  end

  defp preprocess_date(field, %{"to" => to}) do
    {:and, String.to_existing_atom(field), {:lt, to_naive_datetime(to)}}
  end

  defp do_filter(query, {:skip, _field, _value}, _type), do: query

  defp do_filter(query, {:and, field, {:lt, value}}, _type) do
    query
    |> where([q], field(q, ^field) < ^value)
  end

  defp do_filter(query, {:and, field, {:lte, value}}, _type) do
    query
    |> where([q], field(q, ^field) <= ^value)
  end

  defp do_filter(query, {:and, field, {:gt, value}}, _type) do
    query
    |> where([q], field(q, ^field) > ^value)
  end

  defp do_filter(query, {:and, field, {:gte, value}}, _type) do
    query
    |> where([q], field(q, ^field) >= ^value)
  end

  defp do_filter(query, {:and, :order_by, {:desc, field}}, _type) do
    query
    |> order_by([q], {:desc, field(q, ^field)})
  end

  defp do_filter(query, {:and, :order_by, {:asc, field}}, _type) do
    query
    |> order_by([q], {:asc, field(q, ^field)})
  end

  defp do_filter(query, {:and, field, {:contains, nil}}, _type) do
    query
    |> where([q], is_nil(field(q, ^field)))
  end

  defp do_filter(query, {:and, field, {:contains, value}}, type)
       when type in [:id, :integer, :boolean] do
    query
    |> where([q], field(q, ^field) == ^value)
  end

  defp do_filter(query, {:and, field, {:contains, value}}, _type) do
    value =
      value
      |> String.replace("%", "\%")
      |> String.replace("_", "\_")

    value = "%#{value}%"

    query
    |> where([q], ilike(field(q, ^field), ^value))
  end

  defp do_filter(query, {:and, field, {:not, nil}}, _type) do
    query
    |> where([q], not is_nil(field(q, ^field)))
  end

  defp do_filter(query, {:and, field, {:not, value}}, _type) do
    query
    |> where([q], field(q, ^field) != ^value)
  end

  defp to_naive_datetime(string) do
    {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(string), ~T[00:00:00])
    date
  end

  defp maybe_nil("nil"), do: nil
  defp maybe_nil(string), do: string
end
