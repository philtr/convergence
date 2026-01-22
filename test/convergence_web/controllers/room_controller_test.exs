defmodule ConvergenceWeb.RoomControllerTest do
  use ConvergenceWeb.ConnCase, async: true

  defp room_id do
    "room-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  test "GET unknown room returns 404", %{conn: conn} do
    conn = get(conn, ~p"/api/rooms/#{room_id()}")

    assert %{"error" => "room_not_found"} = json_response(conn, 404)
  end

  test "PUT creates room with version 1", %{conn: conn} do
    room_id = room_id()
    state = %{"foo" => "bar"}

    conn = put(conn, ~p"/api/rooms/#{room_id}", %{state: state})
    body = json_response(conn, 200)

    assert body["room_id"] == room_id
    assert body["version"] == 1
    assert body["state"] == state
    assert is_binary(body["updated_at"])
  end

  test "PUT overwrites and increments version", %{conn: conn} do
    room_id = room_id()
    state = %{"foo" => "bar"}

    conn = put(conn, ~p"/api/rooms/#{room_id}", %{state: state})
    _ = json_response(conn, 200)

    new_state = %{"foo" => "baz"}
    conn = put(conn, ~p"/api/rooms/#{room_id}", %{state: new_state})
    body = json_response(conn, 200)

    assert body["version"] == 2
    assert body["state"] == new_state
  end

  test "PUT rejects non-object state", %{conn: conn} do
    conn = put(conn, ~p"/api/rooms/#{room_id()}", %{state: "nope"})

    assert %{"error" => "invalid_state"} = json_response(conn, 422)
  end

  test "PUT rejects payload over max bytes", %{conn: conn} do
    max_bytes = Application.get_env(:convergence, :max_state_bytes, 32_768)
    big_string = String.duplicate("a", max_bytes + 100)

    conn =
      put(conn, ~p"/api/rooms/#{room_id()}", %{
        state: %{"data" => big_string}
      })

    assert %{"error" => "payload_too_large"} = json_response(conn, 413)
  end
end
