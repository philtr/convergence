defmodule ConvergenceWeb.RoomController do
  use ConvergenceWeb, :controller

  alias Convergence.RoomRegistry
  alias Convergence.RoomState

  def show(conn, %{"room_id" => room_id}) do
    case RoomRegistry.get_room(room_id) do
      {:ok, room} ->
        json(conn, RoomState.room_response(room))

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
        with :ok <- RoomState.validate_state(state),
             :ok <- RoomState.validate_size(state) do
          {:ok, room} = RoomRegistry.put_room(room_id, state)
          json(conn, RoomState.room_response(room))
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
end
