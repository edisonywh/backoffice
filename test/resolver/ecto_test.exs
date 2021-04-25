defmodule Resolver.EctoTest do
  use ExUnit.Case
  alias Backoffice.Resolvers.Ecto, as: EctoResolver
  require Ecto.Query

  defmodule Todo do
    use Ecto.Schema

    @primary_key false
    schema "todos" do
      field(:userId, :string)
      field(:id, :string)
      field(:completed, :boolean)
      field(:title, :string)
    end
  end

  defmodule MockRepo do
    def all(query) do
      send(self(), %{
        order_bys: query.order_bys |> Enum.map(& &1.expr),
        preload: query.preloads
      })

      [%Todo{}]
    end

    # This is called by load to find out how many entries there are
    def one(_query) do
      1
    end
  end

  describe "ecto resolver correctly adds options" do
    # This is hacky, ideally we should confirm that the query sent to repo
    # actually includes an order_by clause
    # The answer is here but I dont know how to mock repo just yet
    # https://stephenbussey.com/2019/12/30/verifying-queries-with-ecto-s-prepare-query.html

    test "applies query provided in opts" do
      opts = [
        query: fn q ->
          q
          |> Ecto.Query.order_by([:title])
          |> Ecto.Query.preload(:schema1)
        end,
        repo: MockRepo
      ]

      EctoResolver.load(Todo, opts, %{})

      assert_order_by_and_preload([:title], :schema1)
    end

    test "defaults to default_order_by and preload" do
      opts = [
        default_order_by: [:id],
        preload: [:schema2],
        repo: MockRepo
      ]

      EctoResolver.load(Todo, opts, %{})

      assert_order_by_and_preload([:id], [:schema2])
    end

    test "query overrides default_order_by and preload" do
      opts = [
        preload: [:schema2],
        default_order_by: [:id],
        query: fn q ->
          q
          |> Ecto.Query.order_by([:title])
          |> Ecto.Query.preload(:schema1)
        end,
        repo: MockRepo
      ]

      EctoResolver.load(Todo, opts, %{})

      assert_order_by_and_preload([:title], :schema1)
    end
  end

  def assert_order_by_and_preload(order_by_keys, preload_values) do
    query_options = assert_received %{}
    assert query_options.order_bys == order_by_values(order_by_keys)
    assert query_options.preload == [preload_values]
  end

  def order_by_values(keys) do
    query =
      %Ecto.Query{}
      |> Ecto.Query.order_by(^keys)

    query.order_bys
    |> Enum.map(& &1.expr)
  end
end
