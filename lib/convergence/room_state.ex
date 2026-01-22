defmodule Convergence.RoomState do
  def default_room(room_id) do
    %{
      room_id: room_id,
      version: 0,
      updated_at: DateTime.utc_now(),
      state: nil
    }
  end

  def validate_state(state) when is_map(state) or is_list(state), do: :ok
  def validate_state(_state), do: {:error, :invalid_state}

  def validate_size(state) do
    max_bytes = Application.get_env(:convergence, :max_state_bytes, 32_768)
    payload_bytes = state |> Jason.encode!() |> byte_size()

    if payload_bytes > max_bytes do
      {:error, :payload_too_large}
    else
      :ok
    end
  end

  def room_response(room) do
    %{
      room_id: room.room_id,
      version: room.version,
      updated_at: DateTime.to_iso8601(room.updated_at),
      state: room.state
    }
  end
end
