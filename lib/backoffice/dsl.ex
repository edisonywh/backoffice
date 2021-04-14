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

  defmacro actions(do: block) do
    actions(__CALLER__, block)
  end

  def actions(_caller, block) do
    prelude =
      quote do
        import Backoffice.DSL
        unquote(block)
      end

    postlude =
      quote unquote: false do
        def __actions__(), do: unquote(@actions)

        for {name, body} <- @actions do
          def __action__(unquote(name)), do: unquote(body)
        end
      end

    quote do
      Module.delete_attribute(__MODULE__, :actions)
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro action(name, opts \\ []) do
    quote do
      Backoffice.DSL.__action__(__ENV__, __MODULE__, unquote(name), unquote(opts))
    end
  end

  def __action__(_env, mod, name, opts) do
    opts =
      [enabled: true, confirm: false]
      |> Keyword.merge(opts)
      |> Keyword.take([:type, :enabled, :handler, :confirm, :label, :class])
      |> Enum.into(%{})

    Module.put_attribute(mod, :actions, {name, Macro.escape(opts)})
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

  defmacro embeds_one(name, schema, opts \\ []) do
    quote do
      Backoffice.DSL.__embeds_one__(
        __ENV__,
        __MODULE__,
        unquote(name),
        unquote(schema),
        unquote(opts)
      )
    end
  end

  def __embeds_one__(_env, mod, name, schema, opts) do
    opts =
      opts
      |> Keyword.merge(type: {:embed, %{related: schema}})
      |> Enum.into(%{})

    Module.put_attribute(mod, :index_fields, {name, Macro.escape(opts)})
    Module.put_attribute(mod, :form_fields, {name, Macro.escape(opts)})
  end

  defmacro belongs_to(name, schema, opts \\ []) do
    quote do
      Backoffice.DSL.__belongs_to__(
        __ENV__,
        __MODULE__,
        unquote(name),
        unquote(schema),
        unquote(opts)
      )
    end
  end

  def __belongs_to__(_env, mod, name, _schema, opts) do
    assoc = Module.get_attribute(mod, :resource).__schema__(:association, name)

    opts =
      opts
      |> Keyword.merge(type: {:assoc, assoc})
      |> Enum.into(%{})

    Module.put_attribute(mod, :index_fields, {name, Macro.escape(opts)})
    Module.put_attribute(mod, :form_fields, {name, Macro.escape(opts)})
  end

  defmacro has_one(name, schema, opts \\ []) do
    quote do
      Backoffice.DSL.__has_one__(
        __ENV__,
        __MODULE__,
        unquote(name),
        unquote(schema),
        unquote(opts)
      )
    end
  end

  def __has_one__(_env, mod, name, _schema, opts) do
    assoc = Module.get_attribute(mod, :resource).__schema__(:association, name)

    opts =
      opts
      |> Keyword.merge(type: {:assoc, assoc})
      |> Enum.into(%{})

    Module.put_attribute(mod, :index_fields, {name, Macro.escape(opts)})
    Module.put_attribute(mod, :form_fields, {name, Macro.escape(opts)})
  end

  defmacro has_many(name, schema, opts \\ []) do
    quote do
      Backoffice.DSL.__has_many__(
        __ENV__,
        __MODULE__,
        unquote(name),
        unquote(schema),
        unquote(opts)
      )
    end
  end

  def __has_many__(_env, mod, name, _schema, opts) do
    assoc = Module.get_attribute(mod, :resource).__schema__(:association, name)

    opts =
      opts
      |> Keyword.merge(type: {:assoc, assoc})
      |> Enum.into(%{})

    Module.put_attribute(mod, :index_fields, {name, Macro.escape(opts)})
    Module.put_attribute(mod, :form_fields, {name, Macro.escape(opts)})
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
