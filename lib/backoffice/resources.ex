defmodule Backoffice.Resources do
  def filterable_params(params, fields) do
    filterable =
      fields
      |> Enum.filter(fn {_k, v} ->
        Map.get(v, :filterable, true)
      end)

    allowed_opts =
      Enum.map([:page, :page_size, :order_by] ++ Keyword.keys(filterable), fn k ->
        to_string(k)
      end)

    Map.take(params, allowed_opts)
  end

  def resolve_schema(%{__struct__: Ecto.Query, from: {_source, schema}})
      when is_atom(schema) and not is_nil(schema),
      do: schema

  # Ecto 3 query (this feels dirty...)
  def resolve_schema(%{__struct__: Ecto.Query, from: %{source: {_source, schema}}})
      when is_atom(schema) and not is_nil(schema),
      do: schema

  # Struct
  def resolve_schema(%{__struct__: schema}), do: schema

  # List of structs
  def resolve_schema([%{__struct__: schema} | _rest]), do: schema

  # Schema module itself
  def resolve_schema(schema) when is_atom(schema), do: schema

  # Unable to determine
  def resolve_schema(unknown) do
    raise ArgumentError, "Cannot automatically determine the schema of
      #{inspect(unknown)} - specify the :schema option"
  end

  # This is a pretty hacky way for us to figure out whether or not a path was defined
  # so we can decide whether to render the Create/Edit button.
  defp has_path?(mod, socket, {action, _}) when action in [:new, :edit] do
    try do
      params = if action == :new, do: [], else: 1

      mod =
        mod
        |> Module.concat(Single)
        |> Module.split()
        |> List.delete_at(-2)
        |> Module.concat()

      get_path(mod, socket, action, params)
      true
    rescue
      _ -> false
    end
  end

  defp has_path?(_, _, _), do: true

  def get_path(module, socket, action, resource_or_params) do
    apply(
      Module.concat(socket.router, Helpers),
      :live_path,
      [
        socket,
        build_module(module, action),
        resource_or_params
      ]
    )
  end

  def build_module(module, :new) do
    module
    |> Module.concat(Single)
    |> Module.split()
    |> List.delete_at(-2)
    |> Module.concat()
  end

  def build_module(module, :edit) do
    module
    |> Module.concat(Single)
    |> Module.split()
    |> List.delete_at(-2)
    |> Module.concat()
  end

  def build_module(module, :index) do
    module
    |> Module.concat(Index)
    |> Module.split()
    |> List.delete_at(-2)
    |> Module.concat()
  end

  def get_actions(mod, socket) do
    mod.__actions__()
    |> Enum.filter(fn {_k, v} -> v.enabled end)
    |> Enum.filter(&has_path?(mod, socket, &1))
    |> Enum.split_with(fn {_k, v} -> v.type == :single end)
  end

  def get_form_fields(mod, action) do
    try do
      has_many_keys =
        action
        |> mod.__form__()
        |> Enum.filter(fn {_k, v} -> match?(%{type: {:assoc, %{cardinality: :many}}}, v) end)
        |> Keyword.keys()

      action
      |> mod.__form__()
      |> Enum.split_with(fn {k, _v} -> k in has_many_keys end)
    rescue
      _ ->
        has_many_keys =
          mod.__form__()
          |> Enum.filter(fn {_k, v} -> match?(%{type: {:assoc, %{cardinality: :many}}}, v) end)
          |> Keyword.keys()

        mod.__form__()
        |> Enum.split_with(fn {k, _v} -> k in has_many_keys end)
    end
  end

  def apply_order(<<"[desc]", field::binary>>, field), do: "[asc]#{field}"
  def apply_order(_rest, field), do: "[desc]#{field}"
end
