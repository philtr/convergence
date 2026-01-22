defmodule ConvergenceWeb.RoomController do
  use ConvergenceWeb, :controller

  alias Convergence.RoomRegistry

  def show(conn, %{"room_id" => room_id}) do
    case RoomRegistry.get_room(room_id) do
      {:ok, room} ->
        json(conn, room_response(room))

      :not_found ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "room_not_found"})
    end
  end

  def upsert(conn, %{"room_id" => room_id} = params) do
    case Map.fetch(params, "state") do
      :error ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid_state"})

      {:ok, state} ->
        with :ok <- validate_state(state),
             :ok <- validate_size(state) do
          {:ok, room} = RoomRegistry.put_room(room_id, state)
          json(conn, room_response(room))
        else
          {:error, :invalid_state} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "invalid_state"})

          {:error, :payload_too_large} ->
            conn
            |> put_status(413)
            |> json(%{error: "payload_too_large"})
        end
    end
  end

  defp validate_state(state) when is_map(state) or is_list(state), do: :ok
  defp validate_state(_state), do: {:error, :invalid_state}

  defp validate_size(state) do
    max_bytes = Application.get_env(:convergence, :max_state_bytes, 32_768)
    payload_bytes = state |> Jason.encode!() |> byte_size()

    if payload_bytes > max_bytes do
      {:error, :payload_too_large}
    else
      :ok
    end
  end

  defp room_response(room) do
    %{
      room_id: room.room_id,
      version: room.version,
      updated_at: DateTime.to_iso8601(room.updated_at),
      state: room.state
    }
  end
end
