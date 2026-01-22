defmodule Convergence.RoomRegistry do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{rooms: %{}, subscribers: %{}}, name: __MODULE__)
  end

  def get_room(room_id) do
    GenServer.call(__MODULE__, {:get_room, room_id})
  end

  def put_room(room_id, state) do
    GenServer.call(__MODULE__, {:put_room, room_id, state})
  end

  def subscribe(room_id, pid) do
    GenServer.call(__MODULE__, {:subscribe, room_id, pid})
  end

  def unsubscribe(room_id, pid) do
    GenServer.call(__MODULE__, {:unsubscribe, room_id, pid})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:get_room, room_id}, _from, state) do
    case Map.fetch(state.rooms, room_id) do
      {:ok, room} -> {:reply, {:ok, room}, state}
      :error -> {:reply, :not_found, state}
    end
  end

  def handle_call({:put_room, room_id, new_state}, _from, state) do
    now = DateTime.utc_now()

    room =
      case Map.get(state.rooms, room_id) do
        nil ->
          %{
            room_id: room_id,
            version: 1,
            updated_at: now,
            state: new_state
          }

        existing ->
          %{
            existing
            | version: existing.version + 1,
              updated_at: now,
              state: new_state
          }
      end

    subscribers = Map.get(state.subscribers, room_id, MapSet.new())
    Enum.each(subscribers, &send(&1, {:room_update, room}))

    {:reply, {:ok, room}, %{state | rooms: Map.put(state.rooms, room_id, room)}}
  end

  def handle_call({:subscribe, room_id, pid}, _from, state) do
    subscribers =
      state.subscribers
      |> Map.get(room_id, MapSet.new())
      |> MapSet.put(pid)

    {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, room_id, subscribers)}}
  end

  def handle_call({:unsubscribe, room_id, pid}, _from, state) do
    subscribers =
      state.subscribers
      |> Map.get(room_id, MapSet.new())
      |> MapSet.delete(pid)

    subscribers =
      if MapSet.size(subscribers) == 0 do
        Map.delete(state.subscribers, room_id)
      else
        Map.put(state.subscribers, room_id, subscribers)
      end

    {:reply, :ok, %{state | subscribers: subscribers}}
  end
end
