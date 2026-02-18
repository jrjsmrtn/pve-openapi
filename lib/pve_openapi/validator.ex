# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.Validator do
  @moduledoc """
  Request and response validation against OpenAPI parameter schemas.

  Provides type-level validation of parameter values against the
  OpenAPI schema constraints (type, enum, minimum, maximum, pattern, etc.).
  """

  @doc """
  Validate a single parameter value against its OpenAPI schema.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate_value(term(), map()) :: :ok | {:error, String.t()}
  def validate_value(value, schema) do
    with :ok <- validate_type(value, schema),
         :ok <- validate_enum(value, schema),
         :ok <- validate_minimum(value, schema),
         :ok <- validate_maximum(value, schema),
         :ok <- validate_min_length(value, schema),
         :ok <- validate_max_length(value, schema) do
      validate_pattern(value, schema)
    end
  end

  defp validate_type(_value, %{"type" => "any"}), do: :ok
  defp validate_type(value, %{"type" => "string"}) when is_binary(value), do: :ok
  defp validate_type(value, %{"type" => "integer"}) when is_integer(value), do: :ok
  defp validate_type(value, %{"type" => "number"}) when is_number(value), do: :ok
  defp validate_type(value, %{"type" => "boolean"}) when is_boolean(value), do: :ok
  defp validate_type(value, %{"type" => "array"}) when is_list(value), do: :ok
  defp validate_type(value, %{"type" => "object"}) when is_map(value), do: :ok
  defp validate_type(_value, %{"type" => "null"}), do: :ok
  defp validate_type(_value, schema) when not is_map_key(schema, "type"), do: :ok

  defp validate_type(value, %{"type" => expected}) do
    {:error, "Expected type #{expected}, got #{inspect(value)}"}
  end

  defp validate_enum(_value, schema) when not is_map_key(schema, "enum"), do: :ok

  defp validate_enum(value, %{"enum" => allowed}) do
    str_value = to_string(value)

    if str_value in allowed do
      :ok
    else
      {:error, "Value #{inspect(value)} not in allowed values: #{inspect(allowed)}"}
    end
  end

  defp validate_minimum(_value, schema) when not is_map_key(schema, "minimum"), do: :ok

  defp validate_minimum(value, %{"minimum" => min}) when is_number(value) do
    if value >= min, do: :ok, else: {:error, "Value #{value} below minimum #{min}"}
  end

  defp validate_minimum(_value, _schema), do: :ok

  defp validate_maximum(_value, schema) when not is_map_key(schema, "maximum"), do: :ok

  defp validate_maximum(value, %{"maximum" => max}) when is_number(value) do
    if value <= max, do: :ok, else: {:error, "Value #{value} above maximum #{max}"}
  end

  defp validate_maximum(_value, _schema), do: :ok

  defp validate_min_length(_value, schema) when not is_map_key(schema, "minLength"), do: :ok

  defp validate_min_length(value, %{"minLength" => min}) when is_binary(value) do
    if String.length(value) >= min,
      do: :ok,
      else: {:error, "String length #{String.length(value)} below minimum #{min}"}
  end

  defp validate_min_length(_value, _schema), do: :ok

  defp validate_max_length(_value, schema) when not is_map_key(schema, "maxLength"), do: :ok

  defp validate_max_length(value, %{"maxLength" => max}) when is_binary(value) do
    if String.length(value) <= max,
      do: :ok,
      else: {:error, "String length #{String.length(value)} above maximum #{max}"}
  end

  defp validate_max_length(_value, _schema), do: :ok

  defp validate_pattern(_value, schema) when not is_map_key(schema, "pattern"), do: :ok

  defp validate_pattern(value, %{"pattern" => pattern}) when is_binary(value) do
    case Regex.compile(pattern) do
      {:ok, regex} ->
        if Regex.match?(regex, value),
          do: :ok,
          else: {:error, "Value #{inspect(value)} does not match pattern #{pattern}"}

      {:error, _} ->
        # If pattern can't compile, skip validation
        :ok
    end
  end

  defp validate_pattern(_value, _schema), do: :ok
end
