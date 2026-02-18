# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Convert do
  @moduledoc """
  Convert PVE JSON schema to OpenAPI 3.1.

  Takes the normalized JSON output from `mix pve_openapi.normalize` and produces
  an OpenAPI 3.1 specification.

  ## Usage

      mix pve_openapi.convert <input.json> <output.json> [--version X.Y]
  """
  @shortdoc "Convert PVE JSON schema to OpenAPI 3.1"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, positional} = parse_args(args)

    case positional do
      [input_path, output_path] ->
        convert(input_path, output_path, opts[:version])

      _ ->
        Mix.raise("Usage: mix pve_openapi.convert <input.json> <output.json> [--version X.Y]")
    end
  end

  defp parse_args(args) do
    parse_args(args, [], [])
  end

  defp parse_args(["--version", version | rest], positional, opts) do
    parse_args(rest, positional, [{:version, version} | opts])
  end

  defp parse_args([arg | rest], positional, opts) do
    parse_args(rest, positional ++ [arg], opts)
  end

  defp parse_args([], positional, opts) do
    {opts, positional}
  end

  @doc """
  Convert normalized PVE JSON at `input_path` to OpenAPI 3.1 at `output_path`.

  `pve_version` is an optional string like `"8.3"`.
  """
  def convert(input_path, output_path, pve_version) do
    data = input_path |> File.read!() |> Jason.decode!()

    spec = build_spec(pve_version)
    paths = walk_nodes(data, %{})

    # Sort paths for stable output
    sorted_paths =
      paths
      |> Enum.sort_by(fn {key, _} -> key end)
      |> Enum.into(%{})

    spec = Map.put(spec, "paths", sorted_paths)

    output = Jason.encode!(spec, pretty: true)
    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, output)

    path_count = map_size(sorted_paths)

    operation_count =
      sorted_paths
      |> Map.values()
      |> Enum.reduce(0, fn methods, acc -> acc + map_size(methods) end)

    Mix.shell().info(
      "Converted: #{path_count} paths, #{operation_count} operations → #{output_path}"
    )
  end

  defp build_spec(pve_version) do
    version_str = pve_version || "unknown"

    description =
      "OpenAPI 3.1 specification for the Proxmox VE REST API" <>
        if(pve_version, do: " version #{pve_version}", else: "") <>
        "."

    %{
      "openapi" => "3.1.0",
      "info" => %{
        "title" => "Proxmox Virtual Environment API",
        "version" => version_str,
        "description" => description,
        "license" => %{
          "name" => "AGPL-3.0-or-later",
          "identifier" => "AGPL-3.0-or-later"
        },
        "contact" => %{
          "name" => "Proxmox Server Solutions GmbH",
          "url" => "https://www.proxmox.com"
        }
      },
      "externalDocs" => %{
        "description" => "PVE API Documentation",
        "url" => "https://pve.proxmox.com/pve-docs/api-viewer/"
      },
      "servers" => [
        %{
          "url" => "https://{host}:{port}/api2/json",
          "variables" => %{
            "host" => %{"default" => "localhost"},
            "port" => %{"default" => "8006"}
          }
        }
      ],
      "paths" => %{},
      "components" => %{
        "securitySchemes" => %{
          "apiToken" => %{
            "type" => "apiKey",
            "in" => "header",
            "name" => "Authorization",
            "description" => "PVE API Token: PVEAPIToken=USER@REALM!TOKENID=SECRET"
          },
          "cookie" => %{
            "type" => "apiKey",
            "in" => "cookie",
            "name" => "PVEAuthCookie",
            "description" => "PVE authentication cookie from /access/ticket"
          }
        }
      },
      "security" => [
        %{"apiToken" => []},
        %{"cookie" => []}
      ]
    }
  end

  defp walk_nodes(nodes, paths) when is_list(nodes) do
    Enum.reduce(nodes, paths, fn node, acc ->
      acc = process_node(node, acc)

      case Map.get(node, "children") do
        nil -> acc
        children -> walk_nodes(children, acc)
      end
    end)
  end

  defp process_node(%{"info" => info, "path" => api_path} = _node, paths) when is_map(info) do
    path_entry = Map.get(paths, api_path, %{})

    path_entry =
      Enum.reduce(info, path_entry, fn {method, method_info}, entry ->
        http_method = String.downcase(method)
        operation = build_operation(api_path, method, method_info)
        Map.put(entry, http_method, operation)
      end)

    Map.put(paths, api_path, path_entry)
  end

  defp process_node(_node, paths), do: paths

  defp build_operation(api_path, method, info) do
    %{
      "operationId" => operation_id(api_path, method),
      "summary" => Map.get(info, "name", ""),
      "description" => Map.get(info, "description", ""),
      "externalDocs" => %{
        "description" => "PVE API Documentation",
        "url" => "https://pve.proxmox.com/pve-docs/api-viewer/##{api_path}"
      },
      "tags" => [extract_tag(api_path)]
    }
    |> add_pve_extensions(info)
    |> add_parameters(api_path, method, info)
    |> add_responses(info)
  end

  defp add_pve_extensions(operation, info) do
    operation
    |> put_extension(info, "allowtoken", "x-pve-allowtoken", &to_boolean/1)
    |> put_extension(info, "protected", "x-pve-protected", &to_boolean/1)
    |> put_string_extension(info, "proxyto", "x-pve-proxyto")
    |> maybe_put_permissions(info)
  end

  defp maybe_put_permissions(operation, info) do
    case Map.get(info, "permissions") do
      nil -> operation
      perms -> Map.put(operation, "x-pve-permissions", convert_permissions(perms))
    end
  end

  defp add_parameters(operation, api_path, method, info) do
    http_method = String.downcase(method)
    params_def = get_in(info, ["parameters", "properties"]) || %{}
    additional_props = get_in(info, ["parameters", "additionalProperties"])

    {parameters, request_body_props, required_body} =
      classify_params(params_def, api_path, http_method)

    operation = maybe_put_parameters(operation, parameters)
    maybe_put_request_body(operation, request_body_props, required_body, additional_props)
  end

  defp classify_params(params_def, api_path, http_method) do
    Enum.reduce(params_def, {[], %{}, []}, fn {param_name, param_def},
                                              {params, body_props, req_body} ->
      schema = PveOpenapi.PveTypes.convert_parameter(param_def)
      is_required = !param_def["optional"] || param_def["optional"] == 0

      cond do
        path_param?(param_name, api_path) ->
          param = %{
            "name" => param_name,
            "in" => "path",
            "required" => true,
            "schema" => schema,
            "description" => Map.get(param_def, "description", "")
          }

          {params ++ [param], body_props, req_body}

        http_method in ["get", "delete"] ->
          param = build_query_param(param_name, schema, param_def, is_required)
          {params ++ [param], body_props, req_body}

        true ->
          add_body_param(params, body_props, req_body, param_name, schema, is_required)
      end
    end)
  end

  defp add_body_param(params, body_props, req_body, param_name, schema, is_required) do
    body_props = Map.put(body_props, param_name, schema)
    req_body = if is_required, do: req_body ++ [param_name], else: req_body
    {params, body_props, req_body}
  end

  defp build_query_param(param_name, schema, param_def, is_required) do
    param = %{"name" => param_name, "in" => "query", "schema" => schema}
    param = if is_required, do: Map.put(param, "required", true), else: param

    case Map.get(param_def, "description") do
      nil -> param
      desc -> Map.put(param, "description", desc)
    end
  end

  defp maybe_put_parameters(operation, []), do: operation

  defp maybe_put_parameters(operation, parameters),
    do: Map.put(operation, "parameters", parameters)

  defp maybe_put_request_body(operation, props, _required, _additional) when map_size(props) == 0,
    do: operation

  defp maybe_put_request_body(operation, props, required_body, additional_props) do
    body_schema = %{"type" => "object", "properties" => props}

    body_schema =
      if required_body != [],
        do: Map.put(body_schema, "required", required_body),
        else: body_schema

    body_schema =
      if additional_props != nil,
        do: Map.put(body_schema, "additionalProperties", to_boolean(additional_props)),
        else: body_schema

    request_body = %{
      "required" => required_body != [],
      "content" => %{
        "application/json" => %{"schema" => body_schema},
        "application/x-www-form-urlencoded" => %{"schema" => body_schema}
      }
    }

    Map.put(operation, "requestBody", request_body)
  end

  defp add_responses(operation, info) do
    return_schema = PveOpenapi.PveTypes.convert_returns(Map.get(info, "returns"))
    data_schema = if map_size(return_schema) > 0, do: return_schema, else: %{}

    responses = %{
      "200" => %{
        "description" => "Successful response",
        "content" => %{
          "application/json" => %{
            "schema" => %{
              "type" => "object",
              "properties" => %{"data" => data_schema}
            }
          }
        }
      },
      "400" => %{"description" => "Parameter verification failed"},
      "401" => %{"description" => "Authentication failed"},
      "403" => %{"description" => "Permission check failed"},
      "500" => %{"description" => "Internal server error"}
    }

    Map.put(operation, "responses", responses)
  end

  defp operation_id(path, method) do
    normalized =
      path
      |> String.replace(~r/\{([^}]+)\}/, "\\1")
      |> String.replace("[n]", "-n")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("-")

    "#{String.downcase(method)}-#{normalized}"
  end

  defp extract_tag(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
    |> List.first()
    |> Kernel.||("root")
  end

  defp path_param?(param_name, path) do
    String.contains?(path, "{#{param_name}}")
  end

  defp to_boolean(val) when val in [1, "1", true], do: true
  defp to_boolean(_), do: false

  defp put_extension(operation, info, key, ext_key, transform) do
    case Map.get(info, key) do
      nil -> operation
      val -> Map.put(operation, ext_key, transform.(val))
    end
  end

  defp put_string_extension(operation, info, key, ext_key) do
    case Map.get(info, key) do
      nil -> operation
      val -> Map.put(operation, ext_key, val)
    end
  end

  defp convert_permissions(perms) do
    result = %{}
    result = if perms["user"], do: Map.put(result, "user", perms["user"]), else: result

    result =
      if perms["description"],
        do: Map.put(result, "description", perms["description"]),
        else: result

    if perms["check"], do: Map.put(result, "check", perms["check"]), else: result
  end
end
