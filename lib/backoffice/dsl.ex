defmodule Backoffice.DSL do
  defmacro index(do: block) do
    index(__CALLER__, block)
  end

  def index(_caller, block) do
    prelude =
      quote do
        import Backoffice.DSL
        unquote(block)
      end

    postlude =
      quote unquote: false do
        fields = @index_fields |> Enum.reverse()

        def __index__(), do: unquote(fields)
      end

    quote do
      Module.delete_attribute(__MODULE__, :index_fields)
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro field(name, type \\ :string, opts \\ []) do
    # TODO: Validate type
    quote do
      Backoffice.DSL.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  def __field__(mod, name, type, opts) do
    opts =
      opts
      |> Keyword.merge(type: type)
      |> Enum.into(%{})

    Module.put_attribute(mod, :index_fields, {name, Macro.escape(opts)})
  end
end
