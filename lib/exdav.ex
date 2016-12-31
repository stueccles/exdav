defmodule Exdav do
  import Plug.Conn
  @methods ~w(LOCK UNLOCK OPTIONS PROPFIND PROPPATCH MKCOL DELETE PUT COPY MOVE)

  def init(options) do
  # initialize options
    put_in options[:base_file_path], "/Users/stueccles/Development/elixir"
  end

  def call(conn, opts) do
    opts = put_in(opts[:base_href], href(conn))
    webdav(conn, opts)
  end

  def webdav(conn = %{method: "PUT"}, opts) do
    resource = WebdavResource.from_path_info(conn.request_path, opts)
    {:ok, body, conn} = read_body(conn, length: 1_000_000)
    send_webdav_response(conn, put_resource(resource, body))
  end

  def webdav(conn = %{method: "GET"}, opts) do
    resource = WebdavResource.from_path_info(conn.request_path, opts)
    conn
    |> send_file(HttpStatus.code(:ok), resource.file_path)
  end

  def webdav(conn = %{method: "MKCOL"}, opts) do
    resource = WebdavResource.from_path_info(conn.request_path, opts)
    {:ok, body, conn} = read_body(conn, length: 1_000_000)

    if byte_size(body) > 0 do
      send_webdav_response(conn, :unsupportedmedia)
    else
      case resource.status do
        :notfound -> send_webdav_response(conn, mkcol(resource))
        _ -> send_webdav_response(conn, :notallowed)
      end
    end
  end

  def webdav(conn = %{method: "DELETE"}, opts) do
    resource = WebdavResource.from_path_info(conn.request_path, opts)

    case resource.status do
      :notfound -> send_webdav_response(conn, :notfound)
      _ -> send_webdav_response(conn, delete_resource(resource))
    end
  end

  def webdav(conn = %{method: "COPY"}, opts) do
    resource = WebdavResource.from_path_info(conn.request_path, opts)
    dest = get_req_header(conn, "destination") |> List.first |> URI.parse
    dest_resource = WebdavResource.from_path_info(dest.path, opts)
    overwrite = get_req_header(conn, "overwrite") |> List.first

    case resource.status do
      :notfound -> send_webdav_response(conn, :notfound)
      _ ->
        status = copy_resource(resource, dest_resource, overwrite)
        send_webdav_response(conn, status)
    end
  end

  def webdav(conn = %{method: "MOVE"}, opts) do
    resource = WebdavResource.from_path_info(conn.request_path, opts)
    dest = get_req_header(conn, "destination") |> List.first |> URI.parse
    dest_resource = WebdavResource.from_path_info(dest.path, opts)
    overwrite = get_req_header(conn, "overwrite") |> List.first

    case resource.status do
      :notfound -> send_webdav_response(conn, :notfound)
      _ ->
        status = move_resource(resource, dest_resource, overwrite)
        send_webdav_response(conn, status)
    end
  end

  def webdav(conn = %{method: "OPTIONS"}, _opts) do
    allow = Enum.map(@methods, &String.upcase(&1)) |> Enum.join(", ")
    conn
    |> put_resp_header("DAV", "1,2")
    |> put_resp_header("MS-Author-Via", "DAV")
    |> put_resp_header("Allow", allow)
    |> send_webdav_response(:ok)
  end

  def webdav(conn = %{method: "PROPFIND"}, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)

    try do
      SweetXml.parse(body)

      case WebdavResource.from_path_info(conn.request_path, opts) do
        %{status: :notfound} -> send_webdav_response(conn, :notfound)
        resource ->
          build_resource_set(resource) |> PropXml.propfind_response
          send_webdav_response(conn, :multistatus, xml)
      end
    catch
       :exit, _ -> send_webdav_response(conn, :badrequest)
    end
  end

  def webdav(conn = %{method: "PROPPATCH"}, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, length: 1_000_000)

    try do
      SweetXml.parse(body)

    catch
       :exit, _ -> send_webdav_response(conn, :badrequest)
    end
  end

  def webdav(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_webdav_response(:ok)
  end

  defp build_resource_set(resource) do
    [resource | Enum.map(resource.children, &build_resource_set/1) |> List.flatten ]
  end

  defp send_webdav_response(conn, status, body \\ "") do
    conn
    |> put_resp_content_type("text/xml; charset=\"utf-8\"")
    |> send_resp(HttpStatus.code(status), body)
  end

  defp href(conn) do
    Atom.to_string(conn.scheme) <> "://" <> conn.host <> ":" <> Integer.to_string(conn.port)
  end

  defp move_resource(source_resource, dest_resource = %{status: :notfound}, _overwrite) do
    case File.rename(source_resource.file_path, dest_resource.file_path) do
      :ok -> :created
      {:error, :enoent} -> :conflict
      {:error, _reason} -> :error
    end
  end

  defp move_resource(_, %{status: :ok}, "F") do
    :preconfailed
  end

  defp move_resource(source_resource, dest_resource, _overwrite) do
      File.rm_rf(dest_resource.file_path)
      case File.rename(source_resource.file_path, dest_resource.file_path) do
        :ok-> :nocontent
        {:error, :enoent} -> :conflict
        {:error, _reason} -> :error
      end
  end

  defp copy_resource(_, %{status: :ok}, "F") do
    :preconfailed
  end

  defp copy_resource(source_resource, dest_resource = %{status: :notfound}, _overwrite) do
    case File.cp_r(source_resource.file_path, dest_resource.file_path) do
      {:ok, _filesdirs} -> :created
      {:error, :enoent, _file} -> :conflict
      {:error, _reason, _file} -> :error
    end
  end

  defp copy_resource(source_resource, dest_resource, _overwrite) do
      File.rm_rf(dest_resource.file_path)
      case File.cp_r(source_resource.file_path, dest_resource.file_path) do
        {:ok, _filesdirs} -> :nocontent
        {:error, :enoent, _file} -> :conflict
        {:error, _reason, _file} -> :error
      end
  end

  defp delete_resource(resource) do
    case File.rm_rf(resource.file_path) do
      {:ok, _files} -> :created
      {:error, _file, _reason} -> :error
    end
  end

  defp put_resource(resource, contents) do
    case File.open resource.file_path, [:write] do
      {:ok, file} ->
        IO.binwrite(file, contents)
        File.close(file)
        File.Stat
        :created
      {:error, _reason} -> :error
    end
  end

  defp mkcol(resource) do
    case File.mkdir(resource.file_path) do
      :ok -> :ok
      {:error, :enoent} -> :conflict
      {:error, _reason} -> :error
    end
  end
end
