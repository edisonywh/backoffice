defmodule Backoffice.Resources do
  @callback __index__() :: term()
  @callback row_actions(term()) :: term()

  defmacro __using__(opts) do
    {resolver, resolver_opts} = Keyword.fetch!(opts, :resolver)
    resource = Keyword.fetch!(opts, :resource)
    live_opts = Keyword.get(opts, :live_opts, [])

    quote do
      use Phoenix.LiveView, unquote(live_opts)

      import Backoffice.DSL, only: [index: 1, form: 1, form: 2]

      @behaviour Backoffice.Resources

      Module.register_attribute(__MODULE__, :index_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :form_fields, accumulate: true)

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

      def mount(params, session, socket) do
        socket =
          socket
          |> assign(:fields, __MODULE__.__index__())
          |> assign(:form_fields, __MODULE__.__form__())
          |> assign(:resolver, {unquote(resolver), unquote(resolver_opts)})
          |> assign(:row_actions, __MODULE__.row_actions(socket))
          |> assign(:page_actions, __MODULE__.page_actions(socket))
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
          |> assign_new(:resources, fn ->
            unquote(resolver).load(unquote(resource), unquote(resolver_opts), %{})
          end)

        {:ok, socket}
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
            data: socket.assigns.resources.total_entries
          }
        ]
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
        send_update(Backoffice.FormComponent, [{:id, socket.assigns.resource.id}, {field, value}])

        {:noreply, socket}
      end

      defp apply_action(socket, :new, page_opts) do
        socket
        |> assign(:form_fields, Backoffice.Resources.get_form_fields(__MODULE__, :new))
        |> assign(:resource, %unquote(resource){})
      end

      defp apply_action(socket, :edit, page_opts) do
        socket
        |> assign(:page_title, "Edit")
        |> assign(:form_fields, Backoffice.Resources.get_form_fields(__MODULE__, :edit))
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

      def create, do: false
      def edit, do: false

      def page_actions(socket) do
        if __MODULE__.create() do
          [
            create: %{
              # BUG: If user doesn't define :new in router, this will fail.
              #   How can I dynamically toggle this?
              link: Backoffice.Resources.get_path(__MODULE__, socket, :new, [])
            }
          ]
        else
          []
        end
      end

      def row_actions(socket) do
        if __MODULE__.edit() do
          [
            edit: %{
              link: fn resource ->
                Backoffice.Resources.get_path(__MODULE__, socket, :edit, resource)
              end
            }
          ]
        else
          []
        end
      end

      defoverridable(
        __index__: 0,
        __form__: 0,
        create: 0,
        edit: 0,
        widgets: 1,
        row_actions: 1,
        page_actions: 1
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
end
