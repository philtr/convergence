defmodule ConvergenceWeb.RoomChannelTest do
  use ConvergenceWeb.ChannelCase, async: true

  alias Convergence.RoomRegistry

  defp room_id do
    "room-" <> Integer.to_string(System.unique_integer([:positive]))
  end

  test "join pushes the current room state" do
    room_id = room_id()
    {:ok, _room} = RoomRegistry.put_room(room_id, %{"hello" => "world"})

    {:ok, _, _socket} =
      socket(ConvergenceWeb.SyncSocket, "user", %{})
      |> subscribe_and_join(ConvergenceWeb.RoomChannel, "room:#{room_id}")

    assert_push "state", payload

    assert (payload["room_id"] || payload[:room_id]) == room_id
    assert (payload["state"] || payload[:state]) == %{"hello" => "world"}
  end

  test "broadcasts updates to subscribers" do
    room_id = room_id()

    {:ok, _, _socket} =
      socket(ConvergenceWeb.SyncSocket, "user", %{})
      |> subscribe_and_join(ConvergenceWeb.RoomChannel, "room:#{room_id}")

    assert_push "state", _payload

    {:ok, _room} = RoomRegistry.put_room(room_id, %{"count" => 1})

    assert_push "state", payload

    assert (payload["room_id"] || payload[:room_id]) == room_id
    assert (payload["state"] || payload[:state]) == %{"count" => 1}
  end

  test "accepts state updates from the client" do
    room_id = room_id()

    {:ok, _, socket} =
      socket(ConvergenceWeb.SyncSocket, "user", %{})
      |> subscribe_and_join(ConvergenceWeb.RoomChannel, "room:#{room_id}")

    assert_push "state", _payload

    ref = push(socket, "state:update", %{"state" => %{"count" => 2}})

    assert_reply ref, :ok, reply_payload
    assert (reply_payload["room_id"] || reply_payload[:room_id]) == room_id

    assert_push "state", payload
    assert (payload["state"] || payload[:state]) == %{"count" => 2}
  end
end
