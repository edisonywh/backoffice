defmodule Backoffice.Field do
  use Phoenix.HTML

  import Phoenix.LiveView.Helpers

  def form_field(form, field, opts) do
    type = Map.fetch!(opts, :type)
    opts = Map.delete(opts, :type)

    do_form_field(form, field, type, opts)
  end

  defp do_form_field(form, field, :integer, opts) do
    text_input(form, field, build_opts(:integer, opts))
  end

  defp do_form_field(form, field, :textarea, opts) do
    textarea(form, field, build_opts(:textare, opts))
  end

  defp do_form_field(form, field, {:parameterized, Ecto.Enum, %{values: values}} = type, opts) do
    options = values |> Enum.map(&Phoenix.Naming.humanize/1) |> Enum.zip(values)

    select(form, field, options, build_opts(type, opts))
  end

  # BUG: updating map field doesn't work now
  defp do_form_field(form, field, :map, opts) do
    opts = build_opts(:map, Map.merge(opts, %{value: input_value(form, field)}))

    textarea(form, field, opts)
  end

  defp do_form_field(form, field, :boolean, opts) do
    checkbox(form, field, build_opts(:boolean, opts))
  end

  # TODO: Would be nice to support LiveComponent for more complex component
  #   For example, I would like to have a drop-down suggestion logic as I type.
  defp do_form_field(form, field, :component, opts) do
    component = Map.fetch!(opts, :render)
    opts = Map.merge(opts, %{value: input_value(form, field)})

    live_component(_, component, opts)
  end

  # Q: Are there any pitfall to allowing user render fields like this?
  defp do_form_field(form, field, :custom, opts) do
    render = Map.fetch!(opts, :render)

    render.(form, field)
  end

  defp do_form_field(form, field, {:embed, %{related: schema}}, opts) do
    inputs_for(form, field, fn fp ->
      fields =
        for {k, v} <- schema.__changeset__() do
          {k, %{type: v}}
        end

      [
        {:safe, "<div class=\"p-2\">"},
        Enum.map(fields, fn {field, %{type: type}} ->
          [
            label(fp, field, build_opts(:label, opts)),
            do_form_field(fp, field, type, build_opts(type, opts))
          ]
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  defp do_form_field(form, field, {:assoc, %{related: schema}}, opts) do
    inputs_for(form, field, fn fp ->
      fields = schema.__schema__(:fields)
      types = Enum.map(fields, &schema.__schema__(:type, &1))

      fields =
        for {k, v} <- Enum.zip(fields, types), not is_tuple(v) do
          {k, %{type: v}}
        end

      [
        {:safe, "<div class=\"p-2\">"},
        Enum.map(fields, fn {field, %{type: type}} ->
          [
            label(fp, field, build_opts(:label, opts)),
            do_form_field(fp, field, type, build_opts(type, opts))
          ]
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  defp do_form_field(form, field, type, opts) do
    text_input(form, field, build_opts(type, opts))
  end

  defp build_opts(type, opts) do
    opts = Enum.into(opts, %{})

    %{class: default_style(type, opts)}
    |> Map.merge(opts)
    |> Enum.into([])
  end

  def default_style(:label, _opts) do
    "block text-sm font-medium leading-5 text-gray-700"
  end

  def default_style(:textarea, opts) do
    "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
  end

  def default_style({:embed, _}, opts) do
    "#{maybe_disabled(opts)} mt-2 mb-4 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
  end

  def default_style({:parameterized, Ecto.Enum, _}, opts) do
    "#{maybe_disabled(opts)} mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
  end

  def default_style(:map, opts) do
    default_style(:default, opts)
  end

  def default_style(:boolean, _opts) do
    "focus:ring-indigo-500 h-4 w-4 mt-2 mb-4 text-indigo-600 border-gray-300 rounded transition"
  end

  def default_style(:integer, opts) do
    default_style(:default, opts)
  end

  def default_style(_type, opts) do
    "#{maybe_disabled(opts)} mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
  end

  defp maybe_disabled(opts) do
    case Map.get(opts, :disabled) do
      true -> "bg-gray-200"
      _ -> ""
    end
  end
end
