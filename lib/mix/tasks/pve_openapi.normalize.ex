# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Normalize do
  @moduledoc """
  Extract clean JSON from PVE's apidoc.js.

  PVE's apidoc.js contains `const apiSchema = [...]` followed by ExtJS UI code.
  This task extracts just the JSON array.

  ## Usage

      mix pve_openapi.normalize <input.js> <output.json>
  """
  @shortdoc "Extract clean JSON array from PVE's apidoc.js"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case args do
      [input_path, output_path] ->
        normalize(input_path, output_path)

      _ ->
        Mix.raise("Usage: mix pve_openapi.normalize <input.js> <output.json>")
    end
  end

  @doc """
  Extract clean JSON from `input_path` (apidoc.js) and write to `output_path`.

  Returns `:ok` on success.
  """
  def normalize(input_path, output_path) do
    content = File.read!(input_path)

    # Find the start of the apiSchema array — try both const and var declarations
    marker_pos =
      case :binary.match(content, "const apiSchema = ") do
        {pos, _} ->
          pos

        :nomatch ->
          case :binary.match(content, "var apiSchema = ") do
            {pos, _} -> pos
            :nomatch -> Mix.raise("Could not find apiSchema declaration in #{input_path}")
          end
      end

    # Find the opening bracket
    schema_start = find_char(content, ?[, marker_pos)

    if schema_start == nil do
      Mix.raise("Could not find opening bracket of apiSchema array")
    end

    # Walk brackets to find matching ]
    schema_end = find_matching_bracket(content, schema_start)

    if schema_end == nil do
      Mix.raise("Could not find end of apiSchema array")
    end

    json_str = binary_part(content, schema_start, schema_end - schema_start + 1)

    data =
      case Jason.decode(json_str) do
        {:ok, decoded} -> decoded
        {:error, reason} -> Mix.raise("Failed to parse extracted JSON: #{inspect(reason)}")
      end

    endpoint_count = count_endpoints(data)

    output = Jason.encode!(data, pretty: true)
    File.write!(output_path, output)

    Mix.shell().info("Extracted #{endpoint_count} endpoints from #{input_path} → #{output_path}")
  end

  defp find_char(binary, char, offset) do
    binary
    |> binary_part(offset, byte_size(binary) - offset)
    |> do_find_char(char, offset)
  end

  defp do_find_char(<<c, _rest::binary>>, char, pos) when c == char, do: pos
  defp do_find_char(<<_, rest::binary>>, char, pos), do: do_find_char(rest, char, pos + 1)
  defp do_find_char(<<>>, _char, _pos), do: nil

  defp find_matching_bracket(content, start) do
    content
    |> binary_part(start, byte_size(content) - start)
    |> do_find_matching(0, start)
  end

  defp do_find_matching(<<>>, _depth, _pos), do: nil

  defp do_find_matching(<<"[", rest::binary>>, depth, pos),
    do: do_find_matching(rest, depth + 1, pos + 1)

  defp do_find_matching(<<"]", _rest::binary>>, 1, pos), do: pos

  defp do_find_matching(<<"]", rest::binary>>, depth, pos),
    do: do_find_matching(rest, depth - 1, pos + 1)

  defp do_find_matching(<<_, rest::binary>>, depth, pos),
    do: do_find_matching(rest, depth, pos + 1)

  defp count_endpoints(nodes) when is_list(nodes) do
    Enum.reduce(nodes, 0, fn node, acc ->
      count = if Map.has_key?(node, "info"), do: 1, else: 0
      children_count = count_endpoints(Map.get(node, "children", []))
      acc + count + children_count
    end)
  end

  defp count_endpoints(_), do: 0
end
