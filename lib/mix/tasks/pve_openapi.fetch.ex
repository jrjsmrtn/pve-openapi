# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Fetch do
  @moduledoc """
  Download a pve-docs .deb from the Proxmox apt repo and extract apidoc.js.

  Available versions are discovered dynamically from the Proxmox apt repo
  package index. For each PVE minor version (e.g. 8.3), the latest patch
  release is selected automatically. All distros are scanned; versions
  below `min_version` (currently 7.0) are excluded.

  ## Usage

      mix pve_openapi.fetch <version> [--output-dir specs/raw] [--force]

  ## Examples

      mix pve_openapi.fetch 8.3
      mix pve_openapi.fetch 9.0 --output-dir /tmp/specs --force
  """
  @shortdoc "Download pve-docs .deb and extract apidoc.js"

  use Mix.Task

  @repo_base "http://download.proxmox.com/debian/pve"
  @apidoc_path "usr/share/pve-docs/api-viewer/apidoc.js"
  @min_version {7, 0}

  @impl Mix.Task
  def run(args) do
    {opts, positional} = parse_args(args)

    case positional do
      [version] ->
        output_dir = opts[:output_dir] || "specs/raw"
        force = opts[:force] || false
        fetch_version(version, output_dir, force)

      _ ->
        Mix.raise("Usage: mix pve_openapi.fetch <version> [--output-dir DIR] [--force]")
    end
  end

  @doc """
  Discover available pve-docs versions from the Proxmox apt repo.

  Lists distros under `/dists/`, fetches each `Packages.gz`, parses pve-docs
  entries, groups by major.minor, and returns a map of
  `"major.minor" => %{pkg_version: "x.y.z", filename: "dists/..."}` with
  only the highest patch per minor version.

  Results are cached per process (single fetch per Mix task invocation).
  """
  @spec discover_versions() :: %{String.t() => %{pkg_version: String.t(), filename: String.t()}}
  def discover_versions do
    case Process.get(:pve_openapi_versions) do
      nil ->
        ensure_httpc_started()
        versions = do_discover_versions()
        Process.put(:pve_openapi_versions, versions)
        versions

      cached ->
        cached
    end
  end

  @doc """
  Return sorted list of available PVE minor versions (e.g. `["8.0", "8.1", ...]`).

  Queries the Proxmox apt repo on first call, cached thereafter.
  """
  @spec known_versions() :: [String.t()]
  def known_versions do
    discover_versions() |> Map.keys() |> Enum.sort()
  end

  @doc """
  Download and extract apidoc.js for the given PVE version.

  Returns `:ok` on success (or skip), raises on error.
  """
  @spec fetch_version(String.t(), String.t(), boolean()) :: :ok
  def fetch_version(version, output_dir, force \\ false) do
    output_file = Path.join(output_dir, "apidoc-#{version}.js")

    if File.exists?(output_file) && !force do
      Mix.shell().info("SKIP: #{output_file} already exists")
      :ok
    else
      do_fetch(version, output_dir, output_file)
    end
  end

  # --- Discovery ---

  defp do_discover_versions do
    list_distros()
    |> Enum.flat_map(&fetch_package_index/1)
    |> Enum.filter(&above_min?/1)
    |> group_max_patch()
  end

  defp list_distros do
    url = "#{@repo_base}/dists/"
    body = download!(url)

    Regex.scan(~r/href="([a-z]+)\/"/, body)
    |> Enum.map(fn [_, name] -> name end)
  end

  defp fetch_package_index(distro) do
    url = "#{@repo_base}/dists/#{distro}/pve-no-subscription/binary-amd64/Packages.gz"

    Mix.shell().info("Fetching package index for #{distro}...")

    case try_download(url) do
      {:ok, body} ->
        parse_pve_docs_entries(:zlib.gunzip(body))

      {:error, _} ->
        # Distro may not have pve-no-subscription component
        []
    end
  end

  defp parse_pve_docs_entries(text) do
    text
    |> String.split("\n\n")
    |> Enum.filter(&String.contains?(&1, "Package: pve-docs\n"))
    |> Enum.flat_map(fn stanza ->
      with [_, version] <- Regex.run(~r/^Version: (.+)$/m, stanza),
           [_, filename] <- Regex.run(~r/^Filename: (.+)$/m, stanza),
           {major, minor, patch} <- parse_version(version) do
        [%{major: major, minor: minor, patch: patch, filename: filename}]
      else
        _ -> []
      end
    end)
  end

  defp parse_version(version_str) do
    case Regex.run(~r/^(\d+)\.(\d+)[.\-](\d+)$/, version_str) do
      [_, major, minor, patch] ->
        {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

      _ ->
        nil
    end
  end

  defp above_min?(%{major: major, minor: minor}) do
    {min_major, min_minor} = @min_version
    {major, minor} >= {min_major, min_minor}
  end

  defp group_max_patch(entries) do
    entries
    |> Enum.group_by(fn %{major: maj, minor: min} -> {maj, min} end)
    |> Enum.map(fn {{major, minor}, patches} ->
      best = Enum.max_by(patches, & &1.patch)
      key = "#{major}.#{minor}"
      {key, %{pkg_version: "#{major}.#{minor}.#{best.patch}", filename: best.filename}}
    end)
    |> Enum.into(%{})
  end

  # --- Fetching ---

  defp do_fetch(version, output_dir, output_file) do
    version_map = discover_versions()
    entry = Map.get(version_map, version)

    unless entry do
      known = version_map |> Map.keys() |> Enum.sort() |> Enum.join(", ")
      Mix.raise("Unknown PVE version: #{version}. Available: #{known}")
    end

    deb_url = "#{@repo_base}/#{entry.filename}"

    Mix.shell().info("Downloading pve-docs #{entry.pkg_version} (PVE #{version})...")

    deb_binary = download!(deb_url)

    Mix.shell().info("Extracting apidoc.js...")

    case PveOpenapi.DebExtractor.extract_file_from_deb(deb_binary, @apidoc_path) do
      {:ok, content} ->
        File.mkdir_p!(output_dir)
        File.write!(output_file, content)
        Mix.shell().info("OK: #{output_file} (#{byte_size(content)} bytes)")
        :ok

      {:error, reason} ->
        Mix.raise("Failed to extract apidoc.js: #{reason}")
    end
  end

  # --- HTTP ---

  defp ensure_httpc_started do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
  end

  defp download!(url) do
    case try_download(url) do
      {:ok, body} -> body
      {:error, reason} -> Mix.raise("Download failed (#{url}): #{reason}")
    end
  end

  defp try_download(url) do
    url_charlist = String.to_charlist(url)

    http_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3
      ]
    ]

    case :httpc.request(:get, {url_charlist, []}, http_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _, _}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp parse_args(args), do: parse_args(args, [], [])

  defp parse_args(["--output-dir", dir | rest], positional, opts) do
    parse_args(rest, positional, [{:output_dir, dir} | opts])
  end

  defp parse_args(["--force" | rest], positional, opts) do
    parse_args(rest, positional, [{:force, true} | opts])
  end

  defp parse_args([arg | rest], positional, opts) do
    parse_args(rest, positional ++ [arg], opts)
  end

  defp parse_args([], positional, opts), do: {opts, positional}
end
