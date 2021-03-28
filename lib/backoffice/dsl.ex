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
        index_fields = @index_fields |> Enum.reverse()

        def __index__(), do: unquote(index_fields)
      end

    quote do
      Module.delete_attribute(__MODULE__, :index_fields)
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro form(action \\ nil, do: block) do
    form(__CALLER__, action, block)
  end

  def form(_caller, action, block) do
    prelude =
      quote do
        import Backoffice.DSL
        unquote(block)
      end

    postlude =
      quote bind_quoted: [action: action] do
        form_fields = @form_fields |> Enum.reverse()

        if action do
          def __form__(unquote(action)), do: unquote(form_fields)
        else
          def __form__(), do: unquote(form_fields)
        end
      end

    quote do
      Module.delete_attribute(__MODULE__, :form_fields)
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
    Module.put_attribute(mod, :form_fields, {name, Macro.escape(opts)})
  end
end
