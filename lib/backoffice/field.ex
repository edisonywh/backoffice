defmodule Backoffice.Field do
  use Phoenix.HTML

  import Phoenix.LiveView.Helpers
  import Backoffice.ErrorHelper

  def form_field(form, field, opts) do
    type = Map.fetch!(opts, :type)
    opts = Map.delete(opts, :type)

    do_form_field(form, field, type, opts)
  end

  defp do_form_field(form, field, :integer, opts) do
    text_input(form, field, build_opts(:integer, opts))
  end

  defp do_form_field(form, field, {:array, _type}, opts) do
    opts = Enum.into(opts, %{})

    value =
      case input_value(form, field) do
        "" -> ""
        list when is_list(list) -> Enum.join(list, ",")
      end

    opts =
      build_opts(
        :string,
        Map.merge(opts, %{
          rows: 4,
          value: value
        })
      )

    text_input(form, field, opts)
  end

  defp do_form_field(form, field, :textarea, opts) do
    opts =
      build_opts(
        :textarea,
        Map.merge(opts, %{
          rows: 4,
          value: input_value(form, field)
        })
      )

    textarea(form, field, opts)
  end

  defp do_form_field(form, field, {:parameterized, Ecto.Embedded, %{related: schema}}, _opts) do
    inputs_for(form, field, fn fp ->
      fields =
        for {k, v} <- schema.__changeset__() do
          {k, %{type: v}}
        end

      [
        {:safe, "<div class=\"p-4 shadow rounded-md\">"},
        Enum.map(fields, fn {field, %{type: type}} ->
          [
            {:safe, "<div class=\"mb-4\">"},
            label(fp, field, build_opts(:label, %{})),
            do_form_field(fp, field, type, build_opts(type, %{})),
            error_tag(fp, field),
            {:safe, "</div>"}
          ]
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  defp do_form_field(form, field, {:parameterized, Ecto.Enum, %{values: values}} = type, opts) do
    options = values |> Enum.map(&Phoenix.Naming.humanize/1) |> Enum.zip(values)

    select(form, field, options, build_opts(type, opts))
  end

  defp do_form_field(form, field, :map, opts) do
    opts =
      build_opts(
        :map,
        Map.merge(opts, %{
          rows: 4,
          value: Phoenix.json_library().encode!(input_value(form, field), pretty: true)
        })
      )

    textarea(form, field, opts)
  end

  defp do_form_field(form, field, :boolean, opts) do
    checkbox(form, field, build_opts(:boolean, opts))
  end

  defp do_form_field(form, field, :component, opts) do
    component = Map.fetch!(opts, :render)
    opts = Map.merge(opts, %{value: input_value(form, field)})

    live_component(_, component, opts)
  end

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
            {:safe, "<div class=\"mb-4\">"},
            label(fp, field, build_opts(:label, opts)),
            do_form_field(fp, field, type, build_opts(type, opts)),
            error_tag(fp, field),
            {:safe, "</div>"}
          ]
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  # TODO: Improve the rendering of `belongs_to.
  #   For example it would be good to render a link to the resource
  #   this means we likely have to:
  #     - require user to implement Backoffice for the target resource
  #     - find a way to get the target resource's attributes with just a `schema`/`resource` field.
  #   once we have that, we can think about how to link to that resource directly.
  defp do_form_field(
         form,
         field,
         {:assoc, %Ecto.Association.BelongsTo{related: _schema, related_key: _key}},
         opts
       ) do
    resource = input_value(form, field)

    cond do
      render = Map.get(opts, :render) ->
        render.(resource)

      key = Map.get(opts, :display, :id) ->
        text_input(
          form,
          field,
          build_opts(:default, value: resource[key], disabled: true)
        )
    end
  end

  defp do_form_field(
         form,
         field,
         {:assoc, %Ecto.Association.Has{related: schema, related_key: key}},
         opts
       ) do
    inputs_for(form, field, fn fp ->
      fields = schema.__schema__(:fields)
      types = Enum.map(fields, &schema.__schema__(:type, &1))

      fields =
        for {k, v} <- Enum.zip(fields, types) do
          {k, %{type: v}}
        end

      primary_key = schema.__schema__(:primary_key)

      [
        {:safe, "<div class=\"p-6 col-span-2 bg-gray-100 shadow-inner rounded-md\">"},
        Enum.map(fields, fn {field, %{type: type}} ->
          if field == key do
            hidden_input(fp, field, value: form.data.id)
          else
            opts =
              if field in primary_key,
                do: Map.put(opts, :disabled, true),
                else: opts

            [
              {:safe, "<div class=\"mb-4\">"},
              label(fp, field, build_opts(:label, opts)),
              do_form_field(fp, field, type, build_opts(type, opts)),
              error_tag(fp, field),
              {:safe, "</div>"}
            ]
          end
        end),
        {:safe, "</div>"}
      ]
    end)
  end

  defp do_form_field(form, field, type, opts) do
    text_input(form, field, build_opts(type, opts))
  end

  defp build_opts(:label, opts) do
    opts = Enum.into(opts, %{})

    %{class: default_style(:label)}
    |> Map.merge(opts)
    |> Enum.into([])
  end

  defp build_opts(type, opts) do
    opts = Enum.into(opts, %{})

    class = type |> default_style() |> maybe_disabled(opts)

    %{class: class}
    |> Map.merge(opts)
    |> Enum.into([])
  end

  def default_style(:label) do
    "block text-sm font-medium leading-5 text-gray-700"
  end

  def default_style(:map) do
    default_style(:textarea)
  end

  def default_style(:textarea) do
    "mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md col-span-2"
  end

  def default_style({:embed, _}) do
    "mt-2 mb-4 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
  end

  def default_style({:parameterized, Ecto.Enum, _}) do
    "mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
  end

  def default_style(:select) do
    "mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
  end

  def default_style(:map) do
    default_style(:textarea)
  end

  def default_style(:datetime) do
    "flex-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full min-w-0 rounded-none rounded-r-md sm:text-sm border-gray-300"
  end

  def default_style(:boolean) do
    "focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 rounded transition"
  end

  def default_style(:integer) do
    default_style(:default)
  end

  def default_style(_type) do
    "mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md transition"
  end

  defp maybe_disabled(class, %{disabled: true}) do
    class <> " bg-gray-200"
  end

  defp maybe_disabled(class, _), do: class
end
