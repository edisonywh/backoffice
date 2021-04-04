defmodule Backoffice.Resource.Single do
  defmacro __using__(opts) do
    {resolver, resolver_opts} = Keyword.fetch!(opts, :resolver)
    resource = Keyword.fetch!(opts, :resource)
    live_opts = Keyword.get(opts, :live_opts, [])

    quote do
      use Phoenix.LiveView, unquote(live_opts)

      import Backoffice.DSL, only: [form: 1, form: 2]

      Module.register_attribute(__MODULE__, :form_fields, accumulate: true)

      form do
        schema = Backoffice.Resources.resolve_schema(unquote(resource))

        for {field, type} <- schema.__changeset__() do
          field(field, type)
        end
      end

      def mount(%{"id" => id} = params, session, socket) do
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

      def mount(_params, session, socket) do
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
          "edit.html",
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

      def handle_info({field, value}, socket) do
        send_update(Backoffice.FormComponent, [
          {:id, socket.assigns.resource.id || :new},
          {field, value}
        ])

        {:noreply, socket}
      end

      defp apply_action(socket, :new, page_opts) do
        {_has_many, form_fields} = Backoffice.Resources.get_form_fields(__MODULE__, :new)

        socket
        |> assign(:form_fields, form_fields)
        |> assign(:has_many, [])
        |> assign(:resource, %unquote(resource){})
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

      defoverridable(__form__: 0)
    end
  end
end
