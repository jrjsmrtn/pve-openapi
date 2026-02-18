# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Extract do
  @moduledoc """
  Extract and convert PVE API specs for all (or specified) versions.

  For each version:
  1. Downloads the pve-docs .deb and extracts apidoc.js
  2. Normalizes to clean JSON
  3. Converts to OpenAPI 3.1

  ## Usage

      mix pve_openapi.extract [version...] [--force]

  Without arguments, processes all known versions.

  ## Examples

      mix pve_openapi.extract
      mix pve_openapi.extract 8.3 9.0
      mix pve_openapi.extract --force
  """
  @shortdoc "Extract and convert PVE API specs for all versions"

  use Mix.Task

  alias Mix.Tasks.PveOpenapi.{Convert, Fetch, Normalize}

  @raw_dir "specs/raw"
  @openapi_dir "specs/openapi"

  @impl Mix.Task
  def run(args) do
    {opts, positional} = parse_args(args)
    force = opts[:force] || false

    versions =
      case positional do
        [] -> Fetch.known_versions()
        versions -> versions
      end

    File.mkdir_p!(@raw_dir)
    File.mkdir_p!(@openapi_dir)

    total = length(versions)

    versions
    |> Enum.with_index(1)
    |> Enum.each(fn {version, index} ->
      Mix.shell().info("")
      Mix.shell().info("[#{index}/#{total}] Processing PVE #{version}...")
      Mix.shell().info("---")
      process_version(version, force)
      Mix.shell().info("---")
    end)

    Mix.shell().info("")
    Mix.shell().info("Done. #{total} versions processed.")

    list_generated_specs()
  end

  defp process_version(version, force) do
    raw_js = Path.join(@raw_dir, "apidoc-#{version}.js")
    raw_json = Path.join(@raw_dir, "pve-#{version}.json")
    openapi_json = Path.join(@openapi_dir, "pve-#{version}.json")

    # Step 1: Download and extract apidoc.js
    Fetch.fetch_version(version, @raw_dir, force)

    # Step 2: Normalize
    if File.exists?(raw_json) && !force do
      Mix.shell().info("SKIP: #{raw_json} already exists")
    else
      unless File.exists?(raw_js) do
        Mix.raise("#{raw_js} not found — fetch step failed?")
      end

      Normalize.normalize(raw_js, raw_json)
    end

    # Step 3: Convert to OpenAPI
    unless File.exists?(raw_json) do
      Mix.raise("#{raw_json} not found — normalize step failed?")
    end

    Convert.convert(raw_json, openapi_json, version)
  end

  defp list_generated_specs do
    specs = Path.wildcard(Path.join(@openapi_dir, "pve-*.json"))

    if specs != [] do
      Mix.shell().info("")
      Mix.shell().info("Generated specs:")

      specs
      |> Enum.sort()
      |> Enum.each(fn path ->
        Mix.shell().info("  #{Path.basename(path)}")
      end)
    end
  end

  defp parse_args(args), do: parse_args(args, [], [])

  defp parse_args(["--force" | rest], positional, opts) do
    parse_args(rest, positional, [{:force, true} | opts])
  end

  defp parse_args([arg | rest], positional, opts) do
    parse_args(rest, positional ++ [arg], opts)
  end

  defp parse_args([], positional, opts), do: {opts, positional}
end
