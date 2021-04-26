defmodule Backoffice.Resolver.EctoTest do
  use ExUnit.Case
  alias Backoffice.Resolvers.Ecto, as: EctoResolver
  require Ecto.Query

  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  defmodule Todo do
    use Ecto.Schema

    @primary_key false
    schema "todos" do
      field(:id, :id)
      field(:user_id, :id)
      field(:title, :string)
      field(:completed, :boolean)
    end
  end

  describe "ecto resolver correctly adds options" do
    test "applies query provided in opts" do
      RepoMock
      |> expect(:one, fn query -> 0 end)
      |> expect(:all, fn query ->
        assert has_preloads(query, [:schema1])
        assert has_order_bys(query, [:title])

        # return a result
        []
      end)

      opts = [
        order_by: [:title],
        preload: [:schema1],
        repo: RepoMock
      ]

      EctoResolver.load(Todo, opts, %{})
    end
  end

  defp has_order_bys(query, keys) do
    get_order_by_exprs(query) == create_order_by_exprs(keys)
  end

  defp has_preloads(query, keys) do
    query.preloads == [keys]
  end

  # Create an empty query, add an order_by clause then get the Ecto exprs
  defp create_order_by_exprs(keys) do
    query =
      %Ecto.Query{}
      |> Ecto.Query.order_by(^keys)
      |> get_order_by_exprs()
  end

  defp get_order_by_exprs(query) do
    query.order_bys
    |> Enum.map(& &1.expr)
  end
end
