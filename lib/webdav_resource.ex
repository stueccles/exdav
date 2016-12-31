defmodule WebdavResource do
  require Logger

  defstruct [ :file_path,
              :path_info,
              :resourcetype,
              :properties,
              :href,
              :status,
              :displayname,
              :creationdate,
              :getlastmodified,
              :getetag,
              :getcontenttype,
              :getcontentlength,
              :supportedlock,
              :children  ]


    def from_path_info(path_info, opts, depth \\ 1) do
      file_path = file_path(path_info, opts)
      %__MODULE__{path_info: path_info,
                  file_path: file_path,
                  href: href(path_info, opts)}
      |> set_display_name
      |> set_children(opts, depth)
      |> from_file(File.exists?(file_path))
    end

    defp from_file(resource = %WebdavResource{}, true) do
      case File.stat(resource.file_path) do
        {:ok, info} ->
          resource
          |> set_resource_type(info)
          |> set_status(info)
          |> set_creation_date(info)
          |> set_content_length(info)
        {:error, _} -> nil
      end
    end

    defp from_file(resource = %WebdavResource{}, false) do
      %{resource | status: :notfound}
    end

    defp set_children(resource = %WebdavResource{}, opts, depth) do
      %{resource | children: children(resource.file_path, opts, depth)}
    end

    defp children(_, _, 0) do
      []
    end

    defp children(filepath, opts, depth) do
      Path.wildcard("#{filepath}/*")
      |> Enum.map(&Path.relative_to(&1, opts[:base_file_path]))
      |> Enum.map(&from_path_info(&1, opts, depth - 1))
    end

    defp href(path_info, opts) do
      Path.join(opts[:base_href], path_info)
    end

    defp file_path(path_info, opts) do
      Path.join(opts[:base_file_path], path_info)
    end

    defp set_resource_type(resource = %WebdavResource{}, %{type: :directory} ) do
      %{resource | resourcetype: :collection}
    end

    defp set_resource_type(resource = %WebdavResource{}, _ ) do
      %{resource | resourcetype: :file}
    end

    defp set_display_name(resource = %WebdavResource{}) do
      %{resource | displayname: Path.basename(resource.file_path)}
    end

    defp set_status(resource = %WebdavResource{}, %{access: :none} ) do
      %{resource | status: :unauthorized}
    end

    defp set_status(resource = %WebdavResource{}, %{} ) do
      %{resource | status: :ok}
    end

    defp set_creation_date(resource = %WebdavResource{}, %{ctime: ctime} ) do
      %{resource | creationdate: ctime}
    end

    defp set_content_length(resource = %WebdavResource{}, %{size: size}) do
      %{resource | getcontentlength: size}
    end
end
