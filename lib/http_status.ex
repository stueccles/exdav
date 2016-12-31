defmodule HttpStatus do

  @status_codes [ ok: 200,
                  created: 201,
                  nocontent: 204,
                  multistatus: 207,
                  badrequest: 400,
                  unauthorized: 401,
                  forbidden: 403,
                  notfound: 404,
                  notallowed: 405,
                  preconfailed: 412,
                  unsupportedmedia: 415,
                  locked: 423,
                  conflict: 409,
                  error: 500
                ]

  @status_reason [ ok: "OK",
                  created: "Created",
                  nocontent: "No Content",
                  multistatus: "Multi-Status",
                  badrequest: "Bad Request",
                  unauthorized: "Unauthorized",
                  forbidden: "Forbidden",
                  notfound: "Not Found",
                  notallowed: "Not Allowed",
                  preconfailed: "Precondition Failed",
                  unsupportedmedia: "Unsupported Media Type",
                  locked: "Locked",
                  conflict: "Conflict",
                  error: "Error"
                ]


  def code(status) do
    @status_codes[status]
  end

  def reason(status) do
    @status_reason[status]
  end

  def response(status) do
    "HTTP/1.1 #{code(status)} #{reason(status)}"
  end
end
