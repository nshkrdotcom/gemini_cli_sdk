defmodule GeminiCliSdk.Config do
  @moduledoc "Manages temporary settings files for Gemini CLI configuration."

  alias GeminiCliSdk.Error

  @spec build_settings_file(map() | nil) ::
          {:ok, path :: String.t() | nil, temp_dir :: String.t() | nil}
          | {:error, Error.t()}
  def build_settings_file(nil), do: {:ok, nil, nil}

  def build_settings_file(settings) when is_map(settings) do
    with {:ok, temp_dir} <- create_temp_dir(),
         {:ok, encoded} <- encode_settings(settings),
         settings_path = Path.join(temp_dir, "settings.json"),
         :ok <- File.write(settings_path, encoded) do
      {:ok, settings_path, temp_dir}
    else
      {:error, reason} ->
        {:error,
         Error.new(
           kind: :config_error,
           message: "Failed to write temp settings: #{inspect(reason)}",
           cause: reason
         )}
    end
  end

  @spec cleanup(String.t() | nil) :: :ok
  def cleanup(nil), do: :ok

  def cleanup(temp_dir) do
    File.rm_rf(temp_dir)
    :ok
  end

  @spec read_settings_file(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def read_settings_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            {:ok, data}

          {:error, reason} ->
            {:error,
             Error.new(
               kind: :config_error,
               message: "Invalid JSON in settings file: #{path}",
               cause: reason
             )}
        end

      {:error, reason} ->
        {:error,
         Error.new(
           kind: :config_error,
           message: "Cannot read settings file: #{path}",
           cause: reason
         )}
    end
  end

  @spec merge_settings(map(), map()) :: map()
  def merge_settings(base, overrides) when is_map(base) and is_map(overrides) do
    Map.merge(base, overrides, fn _key, base_val, override_val ->
      if is_map(base_val) and is_map(override_val) do
        merge_settings(base_val, override_val)
      else
        override_val
      end
    end)
  end

  defp create_temp_dir do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
    dir = Path.join(System.tmp_dir!(), "gemini-sdk-#{suffix}")

    case File.mkdir_p(dir) do
      :ok -> {:ok, dir}
      {:error, reason} -> {:error, reason}
    end
  end

  defp encode_settings(settings) do
    case Jason.encode(settings, pretty: true) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, reason}
    end
  end
end
