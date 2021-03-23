defmodule Backoffice.Resources do
  @callback index() :: term()
  @callback row_actions(term()) :: term()
  @callback search_fields() :: list() | nil

  defmacro __using__(opts) do
    {resolver, resolver_opts} = Keyword.fetch!(opts, :resolver)
    resource = Keyword.fetch!(opts, :resource)
    live_opts = Keyword.get(opts, :live_opts, [])

    quote do
      use Phoenix.LiveView, unquote(live_opts)

      @behaviour Backoffice.Resources

      def mount(params, session, socket) do
        socket =
          socket
          |> assign(:search, "")
          |> assign(:search_enabled, __MODULE__.search_fields())
          |> assign(:fields, __MODULE__.index())
          |> assign(:form_fields, __MODULE__.form_fields())
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

      def render(assigns) do
        Phoenix.View.render(
          Backoffice.ResourceView,
          "index.html",
          assigns
        )
      end

      def handle_params(params, _url, socket) do
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      end

      # TODO: Search and Pagination override each other now
      def handle_event("search", page_opts, socket) do
        {:noreply,
         push_patch(socket,
           to: Backoffice.Resources.get_path(__MODULE__, socket, :index, Enum.into(page_opts, []))
         )}
      end

      defp apply_action(socket, :new, page_opts) do
        socket
        |> assign(:resource, %unquote(resource){})
      end

      defp apply_action(socket, :edit, page_opts) do
        socket
        |> assign(:page_title, "Edit")
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
        |> assign(:search, page_opts["search"])
        |> assign(
          :resources,
          unquote(resolver).search(
            __MODULE__,
            unquote(resource),
            unquote(resolver_opts),
            page_opts
          )
        )
      end

      def index do
        for k <- Backoffice.Resources.resolve_schema(unquote(resource)).__schema__(:fields) do
          {k, nil}
        end
      end

      def search_fields, do: nil

      # There's __schema__(:fields) and __changeset__ which are better choices.
      # TODO: remove call to is_tuple/1 and handle embeds/assocs
      def form_fields do
        for {k, v} <- unquote(resource).__changeset__(), not is_tuple(v) do
          {k, %{type: v}}
        end
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
        index: 0,
        search_fields: 0,
        form_fields: 0,
        create: 0,
        edit: 0,
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
end
