# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.DebExtractor do
  @moduledoc """
  Pure Elixir extraction of files from Debian .deb packages.

  Parses the AR archive format and extracts files from the embedded data.tar
  (supports .xz, .gz, and .zst compression).
  """

  @ar_magic "!<arch>\n"
  @ar_header_size 60
  @ar_entry_magic "`\n"

  @doc """
  Extract a file from a .deb package binary.

  Returns `{:ok, binary}` with the file contents, or `{:error, reason}`.

  ## Examples

      {:ok, content} = DebExtractor.extract_file_from_deb(deb_binary, "usr/share/pve-docs/api-viewer/apidoc.js")
  """
  @spec extract_file_from_deb(binary(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def extract_file_from_deb(deb_binary, target_path) do
    with {:ok, ar_entries} <- parse_ar_archive(deb_binary),
         {:ok, {data_tar_binary, format}} <- find_data_tar(ar_entries),
         {:ok, tar_binary} <- decompress_data_tar(data_tar_binary, format) do
      extract_from_tar(tar_binary, target_path)
    end
  end

  @doc """
  Parse an AR archive into a list of `{name, data}` tuples.
  """
  @spec parse_ar_archive(binary()) :: {:ok, [{String.t(), binary()}]} | {:error, String.t()}
  def parse_ar_archive(<<@ar_magic, rest::binary>>) do
    {:ok, parse_ar_entries(rest, [])}
  end

  def parse_ar_archive(_), do: {:error, "not a valid AR archive (bad magic)"}

  defp parse_ar_entries(<<>>, acc), do: Enum.reverse(acc)

  defp parse_ar_entries(binary, acc) when byte_size(binary) < @ar_header_size do
    Enum.reverse(acc)
  end

  defp parse_ar_entries(<<header::binary-size(@ar_header_size), rest::binary>>, acc) do
    <<name_raw::binary-size(16), _mtime::binary-size(12), _uid::binary-size(6),
      _gid::binary-size(6), _mode::binary-size(8), size_raw::binary-size(10), @ar_entry_magic>> =
      header

    name = name_raw |> String.trim_trailing() |> String.trim_trailing("/")
    size = size_raw |> String.trim() |> String.to_integer()

    <<data::binary-size(size), rest2::binary>> = rest

    # AR entries are padded to even byte boundaries
    rest2 =
      case rem(size, 2) do
        1 -> binary_part(rest2, 1, byte_size(rest2) - 1)
        0 -> rest2
      end

    parse_ar_entries(rest2, [{name, data} | acc])
  end

  @doc """
  Find the data.tar entry in AR entries, returning `{data, format}`.

  Looks for `data.tar.xz`, `data.tar.gz`, or `data.tar.zst` (in that order).
  """
  @spec find_data_tar([{String.t(), binary()}]) ::
          {:ok, {binary(), :xz | :gz | :zst}} | {:error, String.t()}
  def find_data_tar(entries) do
    formats = [{"data.tar.xz", :xz}, {"data.tar.gz", :gz}, {"data.tar.zst", :zst}]

    Enum.find_value(formats, {:error, "no data.tar.{xz,gz,zst} found in .deb"}, fn {name, format} ->
      case List.keyfind(entries, name, 0) do
        {^name, data} -> {:ok, {data, format}}
        nil -> nil
      end
    end)
  end

  @doc """
  Decompress a data.tar binary based on its compression format.
  """
  @spec decompress_data_tar(binary(), :xz | :gz | :zst) ::
          {:ok, binary()} | {:error, String.t()}
  def decompress_data_tar(data, :gz) do
    {:ok, :zlib.gunzip(data)}
  rescue
    e -> {:error, "gzip decompression failed: #{inspect(e)}"}
  end

  def decompress_data_tar(data, :xz) do
    case XZ.decompress(data) do
      {:ok, decompressed} -> {:ok, decompressed}
      {:error, reason} -> {:error, "xz decompression failed: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "xz decompression failed: #{inspect(e)}"}
  end

  def decompress_data_tar(data, :zst) do
    {:ok, :ezstd.decompress(data)}
  rescue
    e -> {:error, "zstd decompression failed: #{inspect(e)}"}
  end

  @doc """
  Extract a specific file from an uncompressed tar binary.

  The `target_path` should be without leading `./` — both `./usr/share/...` and
  `usr/share/...` entries will match.
  """
  @spec extract_from_tar(binary(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def extract_from_tar(tar_binary, target_path) do
    case :erl_tar.extract({:binary, tar_binary}, [:memory]) do
      {:ok, entries} -> find_in_tar_entries(entries, target_path)
      {:error, reason} -> {:error, "tar extraction failed: #{inspect(reason)}"}
    end
  end

  defp find_in_tar_entries(entries, target_path) do
    target_normalized = String.trim_leading(target_path, "./")

    result =
      Enum.find_value(entries, fn {entry_name, content} ->
        name = to_string(entry_name) |> String.trim_leading("./")
        if name == target_normalized, do: content
      end)

    case result do
      nil -> {:error, "#{target_path} not found in tar archive"}
      content -> {:ok, content}
    end
  end
end
