defmodule ExdavTest do
  use ExUnit.Case, async: true
  use Plug.Test
  require Logger

  @opts Exdav.init([])

  test "returns from propfind" do
    conn = conn(:propfind, "/Development")
    conn = Exdav.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 400
  end
end
