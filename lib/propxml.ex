defmodule PropXml do
  import XmlBuilder
  use Timex

  def propfind_response(resource = %WebdavResource{}) do
    propfind_response([resource])
  end

  def propfind_response(resources) when is_list(resources) do
    contents = resources |> Enum.map(&resource_element(&1))
    XmlBuilder.doc("D:multistatus", %{"xmlns:D": "DAV:"}, contents)
  end

  defp resource_element(resource) do
    { "D:response", nil, [ { "D:href", nil, resource.href },
                      propstat(resource)] }
  end

  defp propstat(resource) do
    { "D:propstat", nil, [{ "D:prop", nil, properties(resource) }] }
  end

  defp properties(resource) do
    [ {"D:resourcetype", nil, resourcetype(resource.resourcetype)},
      {"D:status", nil, HttpStatus.response(resource.status) },
      {"D:displayname", nil, resource.displayname },
      {"D:creationdate", nil, format_creation_date(resource.creationdate) },
      {"D:getcontentlength", nil, resource.getcontentlength }
    ]
  end

  defp resourcetype(:collection) do
    [{"D:collection", nil, nil}]
  end

  defp resourcetype(type) do
    type
  end

  defp format_creation_date(date) do
      {:ok, date_string} = Date.from(date) |> DateFormat.format("{RFC1123}")
      date_string
  end

end
