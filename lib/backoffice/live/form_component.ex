defmodule Backoffice.FormComponent do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Backoffice.ErrorHelper

  @impl true
  def update(%{resource: resource, resolver: {resolver, opts}, action: action} = assigns, socket) do
    changeset = resolver.change(opts, action, resource)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:resource, resource)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"resource" => resource_params}, socket) do
    resource = socket.assigns.resource
    {resolver, opts} = socket.assigns.resolver

    changeset =
      resolver.change(opts, socket.assigns.action, resource, resource_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"resource" => resource_params}, socket) do
    save_resource(socket, socket.assigns.action, resource_params)
  end

  defp save_resource(socket, action, resource_params) when action in [:new, :edit] do
    resource = socket.assigns.resource
    {resolver, opts} = socket.assigns.resolver

    changeset = resolver.change(opts, action, resource, resource_params)

    action_msg = if action == :new, do: "Created", else: "Updated"

    case resolver.save(opts, action, changeset) do
      {:ok, resource} ->
        {:noreply,
         socket
         # TODO: Fix flash message
         |> put_flash(:success, "#{action_msg} resource [##{resource.id}]!")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
