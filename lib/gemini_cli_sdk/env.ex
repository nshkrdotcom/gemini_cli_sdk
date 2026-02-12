defmodule GeminiCliSdk.Env do
  @moduledoc "Builds the subprocess environment for Gemini CLI invocations."

  @base_env_keys ~w(PATH HOME USER LOGNAME SHELL TERM TMPDIR TEMP TMP)

  @spec build_cli_env(map()) :: map()
  def build_cli_env(overrides \\ %{}) do
    overrides = normalize_overrides(overrides)

    filtered_system_env()
    |> Map.put("NO_COLOR", "1")
    |> Map.put("GEMINI_CLI_SDK_VERSION", sdk_version_tag())
    |> Map.merge(overrides)
  end

  @spec filtered_system_env() :: map()
  def filtered_system_env do
    System.get_env()
    |> Enum.filter(fn {key, _value} ->
      key in @base_env_keys or
        String.starts_with?(key, "GEMINI_") or
        String.starts_with?(key, "GOOGLE_")
    end)
    |> Map.new()
  end

  @spec normalize_overrides(map() | keyword() | nil) :: map()
  def normalize_overrides(nil), do: %{}

  def normalize_overrides(overrides) when is_map(overrides) do
    overrides
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)
    |> Map.new()
  end

  def normalize_overrides(overrides) when is_list(overrides) do
    overrides |> Map.new() |> normalize_overrides()
  end

  @spec sdk_version_tag() :: String.t()
  def sdk_version_tag do
    version = Application.spec(:gemini_cli_sdk, :vsn) || ~c"0.0.0"
    "elixir-#{version}"
  end
end
