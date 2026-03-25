defmodule GeminiCliSdk.Models do
  @moduledoc """
  Centralized model name constants and helpers.

  All model references throughout the SDK flow through this module.
  Override defaults via Application configuration:

      # config/config.exs
      config :gemini_cli_sdk,
        default_model: "gemini-2.5-pro",
        fast_model: "gemini-2.5-flash"

  ## Built-in Models

  | Function | Default | Description |
  |----------|---------|-------------|
  | `default_model/0` | `"gemini-2.5-pro"` | Most capable model |
  | `fast_model/0` | `"gemini-2.5-flash"` | Optimized for speed |

  ## Aliases

  Short aliases expand to full model names via `resolve/1`:

  | Alias | Resolves To |
  |-------|-------------|
  | `"pro"` | `default_model()` |
  | `"default"` | `default_model()` |
  | `"flash"` | `fast_model()` |
  | `"fast"` | `fast_model()` |
  """

  alias CliSubprocessCore.ModelRegistry

  @default_model "gemini-2.5-pro"
  @fast_model "gemini-2.5-flash"

  @aliases %{
    "pro" => @default_model,
    "flash" => @fast_model,
    "default" => @default_model,
    "fast" => @fast_model
  }

  @doc "Returns the default (most capable) model name."
  @spec default_model() :: String.t()
  def default_model do
    case ModelRegistry.default_model(:gemini) do
      {:ok, model} -> model
      {:error, _reason} -> Application.get_env(:gemini_cli_sdk, :default_model, @default_model)
    end
  end

  @doc "Returns the fast model name, optimized for speed."
  @spec fast_model() :: String.t()
  def fast_model do
    resolve("flash")
  end

  @doc "Returns a list of all built-in model identifiers."
  @spec available_models() :: [String.t()]
  def available_models do
    [default_model(), fast_model()]
    |> Enum.uniq()
  end

  @doc """
  Resolves a model name, expanding aliases.

  Accepts full model names as-is, or aliases like `"pro"`, `"flash"`,
  `"default"`, `"fast"`.

  ## Examples

      iex> GeminiCliSdk.Models.resolve("pro")
      "gemini-2.5-pro"

      iex> GeminiCliSdk.Models.resolve("gemini-2.5-flash")
      "gemini-2.5-flash"

      iex> GeminiCliSdk.Models.resolve("custom-model")
      "custom-model"
  """
  @spec resolve(String.t()) :: String.t()
  def resolve(name) when is_binary(name) do
    case ModelRegistry.validate(:gemini, Map.get(@aliases, name, name)) do
      {:ok, model} -> model.id
      {:error, _reason} -> name
    end
  end

  @doc """
  Validates a model value.

  Accepts any non-empty binary string or `nil` (meaning use CLI default).
  Does not restrict to known models -- new models work without SDK updates.

  ## Examples

      iex> GeminiCliSdk.Models.validate("gemini-2.5-pro")
      :ok

      iex> GeminiCliSdk.Models.validate(nil)
      :ok

      iex> GeminiCliSdk.Models.validate(123)
      {:error, "Invalid model: 123. Must be a non-empty string or nil."}
  """
  @spec validate(term()) :: :ok | {:error, String.t()}
  def validate(nil), do: :ok

  def validate(model) do
    case ModelRegistry.validate(:gemini, model) do
      {:ok, _model} -> :ok
      {:error, reason} -> {:error, "Invalid model: #{inspect(model)} (#{inspect(reason)})"}
    end
  end

  @doc "Returns `true` if the model name is a known built-in model or alias."
  @spec known?(String.t()) :: boolean()
  def known?(model) when is_binary(model) do
    model in available_models() or Map.has_key?(@aliases, model)
  end
end
