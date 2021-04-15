defmodule Backoffice.Resource.Single do
  defmacro __using__(opts) do
    resolver = Keyword.fetch!(opts, :resolver)
    resolver_opts = Keyword.get(opts, :resolver_opts, [])
    resource = Keyword.fetch!(opts, :resource)
    live_opts = Keyword.get(opts, :live_opts, [])

    quote do
      use Phoenix.LiveView, unquote(live_opts)

      import Backoffice.DSL, only: [form: 1, form: 2]
      import Backoffice.LiveView.Helpers
      import Phoenix.LiveView.Helpers

      Module.register_attribute(__MODULE__, :form_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :resource, persist: true)
      Module.put_attribute(__MODULE__, :resource, unquote(resource))

      form do
        schema = Backoffice.Resources.resolve_schema(unquote(resource))

        for {field, type} <- schema.__changeset__() do
          field(field, type)
        end
      end

      def mount(params, session, socket) do
        do_mount(params, session, socket)
      end

      def do_mount(%{"id" => id} = params, session, socket) do
        resource = unquote(resolver).get(unquote(resource), unquote(resolver_opts), params)

        has_many_keys =
          __MODULE__.__form__()
          |> Enum.filter(fn {k, v} -> match?(%{type: {:assoc, %{cardinality: :many}}}, v) end)
          |> Keyword.keys()

        {has_many, form_fields} = Backoffice.Resources.get_form_fields(__MODULE__, nil)

        socket =
          socket
          |> assign(:form_fields, form_fields)
          |> assign(:has_many, has_many)
          |> assign(:resolver, {unquote(resolver), unquote(resolver_opts)})
          |> assign(
            :return_to,
            Backoffice.Resources.get_path(
              __MODULE__,
              socket,
              :index,
              %{}
            )
          )
          |> assign(
            :page_title,
            unquote(resource) |> Module.split() |> List.last() |> Phoenix.Naming.humanize()
          )

        {:ok, socket}
      end

      def do_mount(_params, session, socket) do
        {_, form_fields} = Backoffice.Resources.get_form_fields(__MODULE__, nil)

        socket =
          socket
          |> assign(:form_fields, form_fields)
          |> assign(:has_many, [])
          |> assign(:resolver, {unquote(resolver), unquote(resolver_opts)})
          |> assign(:resource, nil)
          |> assign(
            :return_to,
            Backoffice.Resources.get_path(
              __MODULE__,
              socket,
              :index,
              %{}
            )
          )
          |> assign(
            :page_title,
            "New"
          )

        {:ok, socket}
      end

      def render(assigns) do
        Phoenix.View.render(
          Backoffice.ResourceView,
          "single.html",
          assigns
        )
      end

      def handle_params(%{"id" => _id} = params, _url, socket) do
        socket =
          socket
          |> apply_action(:edit, params)
          |> assign(:action, :edit)

        {:noreply, socket}
      end

      def handle_params(params, _url, socket) do
        socket =
          socket
          |> apply_action(:new, params)
          |> assign(:action, :new)

        {:noreply, socket}
      end

      # FIXME: Because `push_event` doesn't work with `push_redirect`, we implement a workaround to allow
      # client-side to initiate redirect.
      def handle_event("redirect", url, socket) do
        {:noreply, push_redirect(socket, to: url)}
      end

      def handle_info({field, value}, socket) do
        send_update(Backoffice.FormComponent, [
          {:id, socket.assigns.resource.id || :new},
          {field, value}
        ])

        {:noreply, socket}
      end

      def __resource__(), do: @resource

      defp apply_action(socket, :new, page_opts) do
        {_has_many, form_fields} = Backoffice.Resources.get_form_fields(__MODULE__, :new)

        socket
        |> assign(:form_fields, form_fields)
        |> assign(:has_many, [])
        |> assign(
          :resource,
          unquote(resolver).get(unquote(resource), unquote(resolver_opts), %{})
        )
      end

      defp apply_action(socket, :edit, page_opts) do
        {has_many, form_fields} = Backoffice.Resources.get_form_fields(__MODULE__, :edit)

        socket
        |> assign(:page_title, "Edit")
        |> assign(:form_fields, form_fields)
        |> assign(:has_many, has_many)
        |> assign(
          :resource,
          unquote(resolver).get(unquote(resource), unquote(resolver_opts), page_opts)
        )
      end

      defoverridable(__form__: 0, mount: 3)
    end
  end
end
