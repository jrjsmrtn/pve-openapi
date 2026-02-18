# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule Mix.Tasks.PveOpenapi.Validate do
  @moduledoc """
  Validate OpenAPI 3.1 spec files.

  Performs structural validation of generated OpenAPI specs: checks required
  top-level keys, version prefix, HTTP method keys, operationId, and responses.

  ## Usage

      mix pve_openapi.validate <spec.json> [<spec2.json> ...]
  """
  @shortdoc "Validate OpenAPI 3.1 spec files"

  use Mix.Task

  @valid_methods ~w(get post put delete patch options head trace)

  @impl Mix.Task
  def run([]) do
    Mix.raise("Usage: mix pve_openapi.validate <spec.json> [<spec2.json> ...]")
  end

  def run(files) do
    results = Enum.map(files, &validate_file/1)
    failures = Enum.count(results, fn {status, _} -> status == :error end)

    if failures > 0 do
      Mix.shell().error("\n#{failures} file(s) failed validation")
      exit({:shutdown, 1})
    else
      Mix.shell().info("\nAll #{length(files)} file(s) passed validation")
    end
  end

  defp validate_file(file) do
    with {:ok, content} <- read_file(file),
         {:ok, spec} <- decode_json(file, content) do
      validate_spec(file, spec)
    end
  end

  defp read_file(file) do
    case File.read(file) do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        Mix.shell().error("FAIL: #{file}")
        Mix.shell().error("  Cannot read file: #{reason}")
        {:error, file}
    end
  end

  defp decode_json(file, content) do
    case Jason.decode(content) do
      {:ok, spec} ->
        {:ok, spec}

      {:error, reason} ->
        Mix.shell().error("FAIL: #{file}")
        Mix.shell().error("  Invalid JSON: #{inspect(reason)}")
        {:error, file}
    end
  end

  defp validate_spec(file, spec) do
    errors =
      []
      |> check_required_keys(spec)
      |> check_openapi_version(spec)
      |> check_info_fields(spec)
      |> check_paths(spec)

    report_result(file, spec, errors)
  end

  defp check_required_keys(errors, spec) do
    errors
    |> check_required_key(spec, "openapi")
    |> check_required_key(spec, "info")
    |> check_required_key(spec, "paths")
  end

  defp check_openapi_version(errors, %{"openapi" => version}) when is_binary(version) do
    if String.starts_with?(version, "3.1"),
      do: errors,
      else: ["openapi version must start with '3.1', got '#{version}'" | errors]
  end

  defp check_openapi_version(errors, %{"openapi" => other}) do
    ["openapi must be a string, got #{inspect(other)}" | errors]
  end

  defp check_openapi_version(errors, _), do: errors

  defp check_info_fields(errors, %{"info" => info}) when is_map(info) do
    errors = if info["title"], do: errors, else: ["info.title is required" | errors]
    if info["version"], do: errors, else: ["info.version is required" | errors]
  end

  defp check_info_fields(errors, _), do: errors

  defp check_paths(errors, %{"paths" => paths}) when is_map(paths) do
    Enum.reduce(paths, errors, fn {path, methods}, errs ->
      validate_path(errs, path, methods)
    end)
  end

  defp check_paths(errors, _), do: errors

  defp report_result(file, spec, []) do
    paths = spec["paths"] || %{}
    path_count = map_size(paths)

    op_count =
      paths
      |> Map.values()
      |> Enum.reduce(0, fn methods, acc -> acc + map_size(methods) end)

    title = get_in(spec, ["info", "title"]) || "?"
    version = get_in(spec, ["info", "version"]) || "?"

    Mix.shell().info(
      "OK: #{file} (#{title} #{version}, #{path_count} paths, #{op_count} operations)"
    )

    {:ok, file}
  end

  defp report_result(file, _spec, errors) do
    Mix.shell().error("FAIL: #{file}")
    Enum.each(Enum.reverse(errors), fn err -> Mix.shell().error("  #{err}") end)
    {:error, file}
  end

  defp validate_path(errors, path, methods) when is_map(methods) do
    Enum.reduce(methods, errors, fn {method, operation}, errs ->
      if method in @valid_methods do
        validate_operation(errs, path, method, operation)
      else
        ["#{path}: invalid HTTP method '#{method}'" | errs]
      end
    end)
  end

  defp validate_path(errors, path, _) do
    ["#{path}: path entry must be an object" | errors]
  end

  defp validate_operation(errors, path, method, operation) when is_map(operation) do
    errors =
      if operation["operationId"],
        do: errors,
        else: ["#{path} #{String.upcase(method)}: missing operationId" | errors]

    if operation["responses"],
      do: errors,
      else: ["#{path} #{String.upcase(method)}: missing responses" | errors]
  end

  defp validate_operation(errors, path, method, _) do
    ["#{path} #{String.upcase(method)}: operation must be an object" | errors]
  end

  defp check_required_key(errors, map, key) do
    if Map.has_key?(map, key), do: errors, else: ["missing required key '#{key}'" | errors]
  end
end
