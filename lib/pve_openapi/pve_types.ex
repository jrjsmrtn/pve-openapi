# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.PveTypes do
  @moduledoc """
  Map PVE custom formats to OpenAPI 3.1 types.

  PVE uses custom "format" strings (e.g., "pve-vmid", "pve-node") on top of
  JSON Schema types. This module maps them to OpenAPI type constraints while
  preserving the original format via x-pve-format.
  """

  # Simple format → OpenAPI type overrides
  # Most PVE formats are strings with patterns; these are the exceptions
  @format_type_overrides %{
    "pve-vmid" => %{"type" => "integer", "minimum" => 100, "maximum" => 999_999_999}
  }

  # Formats that have well-known OpenAPI equivalents
  @format_mappings %{
    "ip" => %{"type" => "string", "format" => "ipv4"},
    "ipv4" => %{"type" => "string", "format" => "ipv4"},
    "ipv6" => %{"type" => "string", "format" => "ipv6"},
    "email-opt" => %{"type" => "string", "format" => "email"},
    "email-list" => %{"type" => "string"},
    "email-or-username-list" => %{"type" => "string"},
    "mac-addr" => %{
      "type" => "string",
      "pattern" => "^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$"
    },
    "dns-name" => %{"type" => "string", "format" => "hostname"},
    "dns-name-list" => %{"type" => "string"},
    "CIDR" => %{"type" => "string"},
    "CIDRv4" => %{"type" => "string"},
    "CIDRv6" => %{"type" => "string"},
    "IPorCIDR" => %{"type" => "string"},
    "IPorCIDRorAlias" => %{"type" => "string"},
    "pem-string" => %{"type" => "string"},
    "pem-certificate-chain" => %{"type" => "string"},
    "urlencoded" => %{"type" => "string"}
  }

  @doc """
  Convert a PVE parameter schema to an OpenAPI 3.1 schema.
  """
  @spec convert_parameter(map()) :: map()
  def convert_parameter(pve_param) do
    schema = %{}

    # Handle PVE type
    pve_type = pve_param["type"] || "string"

    # PVE uses "any" which isn't a JSON Schema type
    schema = if pve_type != "any", do: Map.put(schema, "type", pve_type), else: schema

    # Handle format
    schema = apply_format(schema, pve_param["format"])

    # Copy simple constraints
    schema = put_if_present(schema, "description", pve_param["description"])
    schema = put_if_not_nil(schema, "default", pve_param["default"])
    schema = put_if_not_nil(schema, "minimum", pve_param["minimum"])
    schema = put_if_not_nil(schema, "maximum", pve_param["maximum"])
    schema = put_if_not_nil(schema, "minLength", pve_param["minLength"])
    schema = put_if_not_nil(schema, "maxLength", pve_param["maxLength"])
    schema = put_if_present(schema, "pattern", pve_param["pattern"])
    schema = put_if_present(schema, "enum", pve_param["enum"])
    schema = put_if_present(schema, "x-pve-typetext", pve_param["typetext"])
    schema = put_if_present(schema, "x-pve-format-description", pve_param["format_description"])
    schema = put_if_present(schema, "x-pve-verbose-description", pve_param["verbose_description"])
    put_if_present(schema, "x-pve-requires", pve_param["requires"])
  end

  @doc """
  Convert a PVE return type schema to an OpenAPI 3.1 schema.
  """
  @spec convert_returns(map() | nil) :: map()
  def convert_returns(nil), do: %{}
  def convert_returns(pve_returns) when map_size(pve_returns) == 0, do: %{}

  def convert_returns(%{"type" => "null"}), do: %{"type" => "null"}
  def convert_returns(%{"type" => "any"}), do: %{}

  def convert_returns(pve_returns) do
    schema = %{}

    schema =
      case pve_returns["type"] do
        nil -> schema
        type -> Map.put(schema, "type", type)
      end

    schema = put_if_present(schema, "description", pve_returns["description"])

    schema =
      if pve_returns["type"] == "array" && pve_returns["items"] do
        Map.put(schema, "items", convert_returns(pve_returns["items"]))
      else
        schema
      end

    schema =
      if pve_returns["type"] == "object" && pve_returns["properties"] do
        properties =
          pve_returns["properties"]
          |> Enum.map(fn {name, prop} -> {name, convert_parameter(prop)} end)
          |> Enum.into(%{})

        Map.put(schema, "properties", properties)
      else
        schema
      end

    schema =
      case pve_returns["links"] do
        nil -> schema
        links -> Map.put(schema, "x-pve-links", links)
      end

    schema = put_if_not_nil(schema, "minimum", pve_returns["minimum"])
    put_if_not_nil(schema, "maximum", pve_returns["maximum"])
  end

  # Private helpers

  defp apply_format(schema, nil), do: schema

  defp apply_format(schema, format) when is_map(format) do
    # Complex format (sub-schema) — treat as string with x-pve-format-properties
    schema
    |> Map.put("type", "string")
    |> Map.put("x-pve-format-properties", format)
  end

  defp apply_format(schema, format) when is_binary(format) do
    cond do
      Map.has_key?(@format_type_overrides, format) ->
        schema
        |> Map.merge(@format_type_overrides[format])
        |> Map.put("x-pve-format", format)

      Map.has_key?(@format_mappings, format) ->
        schema
        |> Map.merge(@format_mappings[format])
        |> Map.put("x-pve-format", format)

      true ->
        # Preserve as x-pve-format, keep type as string
        Map.put(schema, "x-pve-format", format)
    end
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp put_if_not_nil(map, _key, nil), do: map
  defp put_if_not_nil(map, key, value), do: Map.put(map, key, value)
end
