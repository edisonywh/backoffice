defmodule Backoffice.FormComponent do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Backoffice.ErrorHelper

  @impl true
  def update(%{resource: resource, resolver: {resolver, opts}} = assigns, socket) do
    changeset = resolver.change(opts, resource)

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
      resolver.change(opts, resource, resource_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"resource" => resource_params}, socket) do
    save_resource(socket, socket.assigns.action, resource_params)
  end

  defp save_resource(socket, :edit, resource_params) do
    resource = socket.assigns.resource
    {resolver, opts} = socket.assigns.resolver

    changeset = resolver.change(opts, resource, resource_params)

    case resolver.save(opts, changeset) do
      {:ok, resource} ->
        {:noreply,
         socket
         # TODO: Fix flash message
         |> put_flash(:success, "Updated resource [##{resource.id}]!")
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
