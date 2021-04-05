defmodule Backoffice.Resource.Index do
  defmacro __using__(opts) do
    {resolver, resolver_opts} = Keyword.fetch!(opts, :resolver)
    resource = Keyword.fetch!(opts, :resource)
    live_opts = Keyword.get(opts, :live_opts, [])

    quote do
      use Phoenix.LiveView, unquote(live_opts)

      import Backoffice.DSL

      Module.register_attribute(__MODULE__, :index_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      Module.register_attribute(__MODULE__, :resource, persist: true)
      Module.put_attribute(__MODULE__, :resource, unquote(resource))

      index do
        schema = Backoffice.Resources.resolve_schema(unquote(resource))

        fields = schema.__schema__(:fields)
        types = Enum.map(fields, &schema.__schema__(:type, &1))

        for {field, type} <- Enum.zip(fields, types), not is_tuple(type) do
          field(field, type)
        end
      end

      actions do
        action(:new, type: :page, label: "Create", handler: &__MODULE__.default_create/2)
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

        {single, page} = Backoffice.Resources.get_actions(__MODULE__, socket)

        socket =
          socket
          |> assign(:fields, __MODULE__.__index__())
          |> assign(:resolver, {unquote(resolver), unquote(resolver_opts)})
          |> assign(:single_actions, Enum.reverse(single))
          |> assign(:page_actions, Enum.reverse(page))
          |> assign(:route_func, fn socket, params, action ->
            Backoffice.Resources.get_path(__MODULE__, socket, params, action)
          end)
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

      def default_create(socket, id) do
        push_redirect(socket, to: Backoffice.Resources.get_path(__MODULE__, socket, :new, %{}))
      end

      def default_edit(socket, id) do
        push_redirect(socket, to: Backoffice.Resources.get_path(__MODULE__, socket, :edit, id))
      end

      defp apply_action(socket, _, page_opts) do
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

      defoverridable(
        __index__: 0,
        __actions__: 0,
        __action__: 1,
        widgets: 1
      )
    end
  end
end
