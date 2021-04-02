defmodule Backoffice.Resources do
  defmacro __using__(opts) do
    {resolver, resolver_opts} = Keyword.fetch!(opts, :resolver)
    resource = Keyword.fetch!(opts, :resource)
    live_opts = Keyword.get(opts, :live_opts, [])

    quote do
      use Phoenix.LiveView, unquote(live_opts)

      import Backoffice.DSL, only: [index: 1, form: 1, form: 2]

      Module.register_attribute(__MODULE__, :index_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :form_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :actions, accumulate: true)

      index do
        schema = Backoffice.Resources.resolve_schema(unquote(resource))

        fields = schema.__schema__(:fields)
        types = Enum.map(fields, &schema.__schema__(:type, &1))

        for {field, type} <- Enum.zip(fields, types), not is_tuple(type) do
          field(field, type)
        end
      end

      form do
        schema = Backoffice.Resources.resolve_schema(unquote(resource))

        for {field, type} <- schema.__changeset__() do
          field(field, type)
        end
      end

      actions do
        action(:new, type: :page, label: "Create", handler: &__MODULE__.default_new/2)
        action(:edit, type: :single, handler: &__MODULE__.default_edit/2)
      end

      def widgets(socket) do
        [
          %Backoffice.PlainWidget{
            title:
              "Total #{
                Phoenix.Naming.humanize(
                  unquote(resource)
                  |> Module.split()
                  |> List.last()
                  |> Phoenix.Naming.humanize()
                )
              }",
            data: socket.assigns.total_entries
          }
        ]
      end

      def mount(params, session, socket) do
        resources = unquote(resolver).load(unquote(resource), unquote(resolver_opts), %{})

        {single, page} =
          __MODULE__.__actions__()
          |> Enum.filter(fn {k, v} -> v.enabled end)
          |> Enum.filter(&Backoffice.Resources.has_path?(__MODULE__, socket, &1))
          |> Enum.split_with(fn {k, v} -> v.type == :single end)

        socket =
          socket
          |> assign(:fields, __MODULE__.__index__())
          |> assign(:form_fields, __MODULE__.__form__())
          |> assign(:resolver, {unquote(resolver), unquote(resolver_opts)})
          |> assign(:single_actions, Enum.reverse(single))
          |> assign(:page_actions, Enum.reverse(page))
          |> assign(:route_func, fn socket, params, action ->
            Backoffice.Resources.get_path(__MODULE__, socket, params, action)
          end)
          |> assign(
            :return_to,
            Backoffice.Resources.get_path(__MODULE__, socket, :index)
          )
          |> assign(
            :page_title,
            unquote(resource) |> Module.split() |> List.last() |> Phoenix.Naming.humanize()
          )
          |> assign(:resources, resources)
          |> assign(:total_entries, resources.total_entries)

        {:ok, socket}
      end

      def render(assigns) do
        Phoenix.View.render(
          Backoffice.ResourceView,
          "index.html",
          assigns
        )
      end

      def handle_params(params, _url, socket) do
        socket =
          socket
          |> apply_action(socket.assigns.live_action, params)
          |> assign(:params, params)

        {:noreply, socket}
      end

      def handle_event("sort", %{"field" => field}, socket) do
        order = Backoffice.Resources.apply_order(socket.assigns.params["order_by"], field)

        params =
          socket.assigns.params
          |> Map.put("order_by", order)

        {:noreply,
         push_patch(socket,
           to: Backoffice.Resources.get_path(__MODULE__, socket, :index, Enum.into(params, []))
         )}
      end

      def handle_event("bo-action", %{"action" => action, "id" => id}, socket) do
        action =
          action
          |> String.to_existing_atom()
          |> __MODULE__.__action__()

        {:noreply, action.handler.(socket, id)}
      end

      def handle_info({:apply_filter, filter, value}, socket) do
        params =
          socket.assigns.params
          |> Map.put(filter, value)

        {:noreply,
         push_patch(socket,
           to: Backoffice.Resources.get_path(__MODULE__, socket, :index, Enum.into(params, []))
         )}
      end

      def handle_info({:remove_filter, filter}, socket) do
        params =
          socket.assigns.params
          |> Map.delete(filter)

        {:noreply,
         push_patch(socket,
           to: Backoffice.Resources.get_path(__MODULE__, socket, :index, Enum.into(params, []))
         )}
      end

      def handle_info({field, value}, socket) do
        send_update(Backoffice.FormComponent, [
          {:id, socket.assigns.resource.id || :new},
          {field, value}
        ])

        {:noreply, socket}
      end

      defp apply_action(socket, :new, page_opts) do
        socket
        |> assign(:form_fields, Backoffice.Resources.get_form_fields(__MODULE__, :new))
        |> assign(:widgets, [])
        |> assign(:resource, %unquote(resource){})
      end

      defp apply_action(socket, :edit, page_opts) do
        socket
        |> assign(:page_title, "Edit")
        |> assign(:form_fields, Backoffice.Resources.get_form_fields(__MODULE__, :edit))
        |> assign(:widgets, [])
        |> assign(
          :resource,
          unquote(resolver).get(unquote(resource), unquote(resolver_opts), page_opts)
        )
      end

      defp apply_action(socket, :index, page_opts) do
        socket
        |> assign(
          :page_title,
          unquote(resource) |> Module.split() |> List.last() |> Phoenix.Naming.humanize()
        )
        |> assign(
          :return_to,
          Backoffice.Resources.get_path(__MODULE__, socket, :index, Enum.into(page_opts, []))
        )
        |> assign(
          :resources,
          unquote(resolver).search(
            __MODULE__,
            unquote(resource),
            unquote(resolver_opts),
            page_opts
          )
        )
        |> assign(:widgets, __MODULE__.widgets(socket))
      end

      def default_new(socket, id) do
        push_patch(socket, to: Backoffice.Resources.get_path(__MODULE__, socket, :new, []))
      end

      def default_edit(socket, id) do
        push_patch(socket, to: Backoffice.Resources.get_path(__MODULE__, socket, :edit, id))
      end

      defoverridable(
        __index__: 0,
        __form__: 0,
        __actions__: 0,
        widgets: 1
      )
    end
  end

  def resolve_schema(%{__struct__: Ecto.Query, from: {_source, schema}})
      when is_atom(schema) and not is_nil(schema),
      do: schema

  # Ecto 3 query (this feels dirty...)
  def resolve_schema(%{__struct__: Ecto.Query, from: %{source: {_source, schema}}})
      when is_atom(schema) and not is_nil(schema),
      do: schema

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
  def has_path?(mod, socket, {action, _}) when action in [:new, :edit] do
    try do
      params = if action == :new, do: [], else: 1
      get_path(mod, socket, action, params)
      true
    rescue
      _ -> false
    end
  end

  def has_path?(_, _, _), do: true

  # TODO: this is so hacky, plz send halp.
  def get_path(module, socket, action, resource_or_params \\ []) do
    apply(
      Module.concat(socket.router, Helpers),
      get_path(module),
      [
        socket,
        action,
        resource_or_params
      ]
    )
  end

  # TODO: this is so hacky, plz send halp.
  defp get_path(mod) do
    mod
    |> Module.split()
    |> Enum.drop(2)
    |> Enum.map(&String.trim_trailing(&1, "Live"))
    |> Enum.map(&String.downcase(&1))
    |> List.insert_at(3, "path")
    |> Enum.join("_")
    |> String.to_existing_atom()
  end

  def get_form_fields(mod, action) do
    try do
      mod.__form__(action)
    rescue
      _ -> mod.__form__()
    end
  end

  def apply_order(<<"[desc]", field::binary>>, field), do: "[asc]#{field}"
  def apply_order(_rest, field), do: "[desc]#{field}"
end
