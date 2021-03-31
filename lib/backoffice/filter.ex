defmodule Backoffice.Filter do
  @moduledoc """
  This is a filtering engine that translates query params into Ecto filters.

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

  import Ecto.Query

  def preprocess({"page", value}) do
    {:skip, :page, value}
  end

  def preprocess({"page_size", value}) do
    {:skip, :page_num, value}
  end

  def preprocess({field, <<"[gte]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:gte, String.to_integer(value)}}
  end

  def preprocess({field, <<"[gt]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:gt, String.to_integer(value)}}
  end

  def preprocess({field, <<"[lte]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:lte, String.to_integer(value)}}
  end

  def preprocess({field, <<"[lt]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:lt, String.to_integer(value)}}
  end

  def preprocess({field, <<"[not]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:not, maybe_nil(value)}}
  end

  def preprocess({field, <<"[desc]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:desc, String.to_existing_atom(value)}}
  end

  def preprocess({field, <<"[asc]", value::binary>>}) do
    {:and, String.to_existing_atom(field), {:asc, String.to_existing_atom(value)}}
  end

  def preprocess({field, value}) when is_binary(value) do
    {:and, String.to_existing_atom(field), {:contains, maybe_nil(value)}}
  end

  # If it is a query for datetime with `from` & `to` field, we convert it to
  # a `gt` from and a `lt` to, since that's what the Ecto query looks like.
  def preprocess({field, value}) when is_map(value) do
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

  def apply_filter(query, {:skip, _field, _value}, _type), do: query

  def apply_filter(query, {:and, field, {:lt, value}}, _type) do
    query
    |> where([q], field(q, ^field) < ^value)
  end

  def apply_filter(query, {:and, field, {:lte, value}}, _type) do
    query
    |> where([q], field(q, ^field) <= ^value)
  end

  def apply_filter(query, {:and, field, {:gt, value}}, _type) do
    query
    |> where([q], field(q, ^field) > ^value)
  end

  def apply_filter(query, {:and, field, {:gte, value}}, _type) do
    query
    |> where([q], field(q, ^field) >= ^value)
  end

  def apply_filter(query, {:and, :order_by, {:desc, field}}, _type) do
    query
    |> order_by([q], {:desc, field(q, ^field)})
  end

  def apply_filter(query, {:and, :order_by, {:asc, field}}, _type) do
    query
    |> order_by([q], {:asc, field(q, ^field)})
  end

  def apply_filter(query, {:and, field, {:contains, nil}}, _type) do
    query
    |> where([q], is_nil(field(q, ^field)))
  end

  def apply_filter(query, {:and, field, {:contains, value}}, type)
      when type in [:id, :integer, :boolean] do
    query
    |> where([q], field(q, ^field) == ^value)
  end

  def apply_filter(query, {:and, field, {:contains, value}}, _type) do
    value =
      value
      |> String.replace("%", "\%")
      |> String.replace("_", "\_")

    value = "%#{value}%"

    query
    |> where([q], ilike(field(q, ^field), ^value))
  end

  def apply_filter(query, {:and, field, {:not, nil}}, _type) do
    query
    |> where([q], not is_nil(field(q, ^field)))
  end

  def apply_filter(query, {:and, field, {:not, value}}, _type) do
    query
    |> where([q], field(q, ^field) != ^value)
  end

  def to_naive_datetime(string) do
    {:ok, date} = NaiveDateTime.new(Date.from_iso8601!(string), ~T[00:00:00])
    date
  end

  def maybe_nil("nil"), do: nil
  def maybe_nil(string), do: string
end
