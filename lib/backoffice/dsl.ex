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

  defmacro field(name, type \\ nil, opts \\ []) do
    quote do
      Backoffice.DSL.__field__(__ENV__, __MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  def __field__(env, mod, name, type, opts) do
    # TODO: Validate types
    validate_value!(env, type)

    opts =
      opts
      |> Keyword.merge(type: type || :string)
      |> Enum.into(%{})

    Module.put_attribute(mod, :index_fields, {name, Macro.escape(opts)})
    Module.put_attribute(mod, :form_fields, {name, Macro.escape(opts)})
  end

  defp validate_value!(env, list) when is_list(list) do
    if Keyword.get(list, :render) != nil do
      raise CompileError,
        description: "If you provide :render, you must also provide :type.",
        file: env.file,
        line: env.line
    end
  end

  defp validate_value!(_, _), do: :ok
end
