defmodule ConvergenceWeb.RoomStreamController do
  use ConvergenceWeb, :controller

  alias Convergence.RoomRegistry

  def stream(conn, %{"room_id" => room_id}) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    :ok = RoomRegistry.subscribe(room_id, self())

    try do
      conn = send_initial(conn, room_id)
      stream_loop(conn, room_id)
    after
      RoomRegistry.unsubscribe(room_id, self())
    end
  end

  defp send_initial(conn, room_id) do
    room =
      case RoomRegistry.get_room(room_id) do
        {:ok, room} -> room
        :not_found -> %{room_id: room_id, version: 0, updated_at: DateTime.utc_now(), state: nil}
      end

    {:ok, conn} = send_event(conn, room)
    conn
  end

  defp stream_loop(conn, room_id) do
    heartbeat_ms = heartbeat_ms()

    receive do
      {:room_update, room} ->
        case send_event(conn, room) do
          {:ok, conn} -> stream_loop(conn, room_id)
          {:error, _reason} -> conn
        end
    after
      heartbeat_ms ->
        case chunk(conn, ": heartbeat\n\n") do
          {:ok, conn} -> stream_loop(conn, room_id)
          {:error, _reason} -> conn
        end
    end
  end

  defp send_event(conn, room) do
    payload =
      room
      |> room_response()
      |> Jason.encode!()

    chunk(conn, "event: state\ndata: #{payload}\n\n")
  end

  defp room_response(room) do
    %{
      room_id: room.room_id,
      version: room.version,
      updated_at: DateTime.to_iso8601(room.updated_at),
      state: room.state
    }
  end

  defp heartbeat_ms do
    case Application.fetch_env(:convergence, :heartbeat_ms) do
      {:ok, ms} when is_integer(ms) and ms > 0 ->
        ms

      _ ->
        Application.get_env(:convergence, :heartbeat_seconds, 15) * 1_000
    end
  end
end
