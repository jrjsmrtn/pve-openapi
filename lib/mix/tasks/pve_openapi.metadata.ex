# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Metadata do
  @moduledoc """
  Generate specs/metadata.json from OpenAPI specs.

  Reads each `specs/openapi/pve-*.json` file, counts paths and operations,
  and writes a metadata index to `specs/metadata.json`.

  ## Usage

      mix pve_openapi.metadata
  """
  @shortdoc "Generate specs/metadata.json from OpenAPI specs"

  use Mix.Task

  @specs_dir "specs/openapi"
  @output_path "specs/metadata.json"

  @impl Mix.Task
  def run(_args) do
    files = list_spec_files(@specs_dir)

    versions = Enum.flat_map(files, fn file -> build_version_entry(@specs_dir, file) end)

    metadata = %{
      "generated" => Date.utc_today() |> Date.to_iso8601(),
      "versions" => versions
    }

    File.mkdir_p!("specs")
    File.write!(@output_path, Jason.encode!(metadata, pretty: true))

    Mix.shell().info("Generated #{@output_path} (#{length(versions)} versions)")
  end

  defp list_spec_files(specs_dir) do
    case File.ls(specs_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&String.match?(&1, ~r/^pve-.*\.json$/))
        |> Enum.sort()

      {:error, _} ->
        Mix.shell().error("No specs directory found at #{specs_dir}")
        []
    end
  end

  defp build_version_entry(specs_dir, file) do
    path = Path.join(specs_dir, file)

    with {:ok, content} <- File.read(path),
         {:ok, spec} <- Jason.decode(content) do
      paths = spec["paths"] || %{}
      path_count = map_size(paths)

      op_count =
        paths
        |> Map.values()
        |> Enum.reduce(0, fn methods, acc -> acc + map_size(methods) end)

      version =
        file
        |> String.replace_prefix("pve-", "")
        |> String.replace_suffix(".json", "")

      [%{"version" => version, "paths" => path_count, "operations" => op_count, "file" => file}]
    else
      _ ->
        Mix.shell().error("SKIP: #{path} could not be read")
        []
    end
  end
end
