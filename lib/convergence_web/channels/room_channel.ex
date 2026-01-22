defmodule ConvergenceWeb.RoomChannel do
  use ConvergenceWeb, :channel

  alias Convergence.RoomRegistry
  alias Convergence.RoomState

  def join("room:" <> room_id, _params, socket) do
    :ok = RoomRegistry.subscribe(room_id, self())

    room =
      case RoomRegistry.get_room(room_id) do
        {:ok, room} -> room
        :not_found -> RoomState.default_room(room_id)
      end

    send(self(), {:room_init, room})

    {:ok, assign(socket, :room_id, room_id)}
  end

  def handle_in("state:update", %{"state" => state}, socket) do
    room_id = socket.assigns.room_id

    with :ok <- RoomState.validate_state(state),
         :ok <- RoomState.validate_size(state) do
      {:ok, room} = RoomRegistry.put_room(room_id, state)
      {:reply, {:ok, RoomState.room_response(room)}, socket}
    else
      {:error, :invalid_state} ->
        {:reply, {:error, %{error: "invalid_state"}}, socket}

      {:error, :payload_too_large} ->
        {:reply, {:error, %{error: "payload_too_large"}}, socket}
    end
  end

  def handle_info({:room_init, room}, socket) do
    push(socket, "state", RoomState.room_response(room))
    {:noreply, socket}
  end

  def handle_info({:room_update, room}, socket) do
    push(socket, "state", RoomState.room_response(room))
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    RoomRegistry.unsubscribe(socket.assigns.room_id, self())
    :ok
  end
end
