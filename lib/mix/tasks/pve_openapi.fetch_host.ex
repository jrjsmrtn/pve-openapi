# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.FetchHost do
  @moduledoc """
  Fetch API schema from a live PVE host.

  ## Usage

      mix pve_openapi.fetch_host <host> <port> <output-file> --token <api-token>

  ## Examples

      mix pve_openapi.fetch_host pve.example.com 8006 specs/raw/apidoc-current.js \\
        --token "PVEAPIToken=user@pve!token=secret"
  """
  @shortdoc "Fetch API schema from a live PVE host"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, positional} = parse_args(args)

    case {positional, opts[:token]} do
      {[host, port, output_file], token} when is_binary(token) ->
        fetch_from_host(host, port, token, output_file)

      _ ->
        Mix.raise(
          "Usage: mix pve_openapi.fetch_host <host> <port> <output-file> --token <api-token>"
        )
    end
  end

  defp fetch_from_host(host, port, token, output_file) do
    ensure_httpc_started()

    Mix.shell().info("Fetching API schema from #{host}:#{port}...")

    url = ~c"https://#{host}:#{port}/api2/json"

    headers = [{~c"Authorization", String.to_charlist(token)}]

    ssl_opts = [
      ssl: [
        verify: :verify_none
      ]
    ]

    case :httpc.request(:get, {url, headers}, ssl_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        File.mkdir_p!(Path.dirname(output_file))
        File.write!(output_file, body)
        Mix.shell().info("OK: #{output_file} (#{byte_size(body)} bytes)")

      {:ok, {{_, status, _}, _headers, _body}} ->
        Mix.raise("HTTP #{status} from #{host}:#{port}")

      {:error, reason} ->
        Mix.raise("Request failed: #{inspect(reason)}")
    end
  end

  defp ensure_httpc_started do
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
  end

  defp parse_args(args), do: parse_args(args, [], [])

  defp parse_args(["--token", token | rest], positional, opts) do
    parse_args(rest, positional, [{:token, token} | opts])
  end

  defp parse_args([arg | rest], positional, opts) do
    parse_args(rest, positional ++ [arg], opts)
  end

  defp parse_args([], positional, opts), do: {opts, positional}
end
