# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.SchemaQuality do
  @moduledoc """
  Analyze response schema completeness across PVE API versions.

  PVE's `returns` definitions vary in detail — some endpoints return fully
  typed objects with properties, while others return `null` or have no schema
  at all. This module classifies each endpoint's response quality to help
  consumers decide which endpoints are worth generating typed resources for.

  ## Quality Levels

  - `:rich` — response has typed properties (object with properties, array with items, scalar type)
  - `:partial` — response has a type but no structural detail (e.g., object without properties)
  - `:opaque` — response is `null`, missing, or has no useful type information

  ## Usage

      PveOpenapi.SchemaQuality.analyze_endpoint(spec, "/version", :get)
      #=> {:rich, %{type: "object", property_count: 5}}

      PveOpenapi.SchemaQuality.quality_summary("9.0")
      #=> %{rich: 390, partial: 51, opaque: 205, total: 646}
  """

  alias PveOpenapi.Spec

  @type quality :: :rich | :partial | :opaque
  @type analysis :: {quality(), map()}

  @doc """
  Analyze a single endpoint's response schema quality.

  Returns `{quality, details}` where details include the response data type
  and property count (if applicable).
  """
  @spec analyze_endpoint(map(), String.t(), atom()) :: analysis() | :error
  def analyze_endpoint(spec, path, method) do
    case Spec.operation(spec, path, method) do
      {:ok, op} ->
        schema = get_in(op, ["responses", "200", "content", "application/json", "schema"])
        data_schema = get_in(schema || %{}, ["properties", "data"]) || %{}
        classify(data_schema)

      :error ->
        :error
    end
  end

  @doc """
  Generate a per-endpoint quality report for a version.

  Returns a list of `%{path, method, quality, details}` maps.
  """
  @spec quality_report(String.t()) :: [map()]
  def quality_report(version) do
    spec = PveOpenapi.spec!(version)

    PveOpenapi.endpoints(version)
    |> Enum.map(fn endpoint ->
      {quality, details} = analyze_endpoint(spec, endpoint.path, endpoint.method)
      %{path: endpoint.path, method: endpoint.method, quality: quality, details: details}
    end)
  end

  @doc """
  Return aggregate quality statistics for a version.
  """
  @spec quality_summary(String.t()) :: map()
  def quality_summary(version) do
    report = quality_report(version)
    counts = Enum.frequencies_by(report, & &1.quality)

    %{
      version: version,
      rich: Map.get(counts, :rich, 0),
      partial: Map.get(counts, :partial, 0),
      opaque: Map.get(counts, :opaque, 0),
      total: length(report)
    }
  end

  @doc """
  Compare response schema quality between two versions.

  Returns endpoints that improved or degraded in quality.
  """
  @spec quality_diff(String.t(), String.t()) :: %{improved: [map()], degraded: [map()]}
  def quality_diff(from_version, to_version) do
    from_report = quality_report(from_version) |> Map.new(&{{&1.path, &1.method}, &1.quality})
    to_report = quality_report(to_version) |> Map.new(&{{&1.path, &1.method}, &1.quality})

    quality_rank = %{opaque: 0, partial: 1, rich: 2}

    common_keys =
      MapSet.intersection(MapSet.new(Map.keys(from_report)), MapSet.new(Map.keys(to_report)))

    {improved, degraded} =
      common_keys
      |> Enum.reduce({[], []}, fn {path, method} = key, {imp, deg} ->
        from_q = from_report[key]
        to_q = to_report[key]

        cond do
          quality_rank[to_q] > quality_rank[from_q] ->
            {[%{path: path, method: method, from: from_q, to: to_q} | imp], deg}

          quality_rank[to_q] < quality_rank[from_q] ->
            {imp, [%{path: path, method: method, from: from_q, to: to_q} | deg]}

          true ->
            {imp, deg}
        end
      end)

    %{
      improved: Enum.sort_by(improved, &{&1.path, &1.method}),
      degraded: Enum.sort_by(degraded, &{&1.path, &1.method})
    }
  end

  # --- Classification ---

  defp classify(%{"type" => "null"}), do: {:opaque, %{type: "null"}}
  defp classify(%{"type" => nil}), do: {:opaque, %{type: nil}}
  defp classify(schema) when schema == %{}, do: {:opaque, %{type: nil}}

  defp classify(%{"type" => "object", "properties" => props})
       when is_map(props) and map_size(props) > 0 do
    {:rich, %{type: "object", property_count: map_size(props)}}
  end

  defp classify(%{"type" => "array", "items" => %{"properties" => props}})
       when is_map(props) and map_size(props) > 0 do
    {:rich, %{type: "array", item_property_count: map_size(props)}}
  end

  defp classify(%{"type" => "array", "items" => items})
       when is_map(items) and map_size(items) > 0 do
    {:rich, %{type: "array"}}
  end

  defp classify(%{"type" => type}) when type in ~w(string integer number boolean) do
    {:rich, %{type: type}}
  end

  defp classify(%{"type" => "object"}) do
    {:partial, %{type: "object", property_count: 0}}
  end

  defp classify(%{"type" => "array"}) do
    {:partial, %{type: "array"}}
  end

  defp classify(schema) do
    if map_size(schema) > 0 do
      {:partial, %{type: schema["type"]}}
    else
      {:opaque, %{type: nil}}
    end
  end
end
