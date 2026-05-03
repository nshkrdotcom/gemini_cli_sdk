defmodule GeminiCliSdk.GovernedLaunch do
  @moduledoc false

  alias CliSubprocessCore.{Command, ExecutionSurface, GovernedAuthority}
  alias GeminiCliSdk.Options

  @option_smuggling_fields [
    :cli_command,
    :cwd,
    :settings,
    :execution_surface
  ]

  @command_smuggling_fields [
    :cli_command,
    :command,
    :executable,
    :command_spec,
    :cli_path,
    :cd,
    :cwd,
    :env,
    :settings,
    :execution_surface,
    :clear_env?,
    :clear_env
  ]

  @spec authority(Options.t() | keyword() | map() | nil) ::
          {:ok, GovernedAuthority.t() | nil} | {:error, term()}
  def authority(%Options{governed_authority: authority}), do: GovernedAuthority.new(authority)

  def authority(opts) when is_list(opts),
    do: GovernedAuthority.new(Keyword.get(opts, :governed_authority))

  def authority(%{} = opts), do: GovernedAuthority.new(Map.get(opts, :governed_authority))
  def authority(nil), do: {:ok, nil}

  @spec governed?(Options.t() | keyword() | map() | nil) :: boolean()
  def governed?(input) do
    case authority(input) do
      {:ok, %GovernedAuthority{}} -> true
      _ -> false
    end
  end

  @spec validate_options(Options.t()) :: :ok | {:error, term()}
  def validate_options(%Options{} = options) do
    with {:ok, authority} <- authority(options) do
      validate_options(options, authority)
    end
  end

  @spec validate_options!(Options.t()) :: Options.t()
  def validate_options!(%Options{} = options) do
    case validate_options(options) do
      :ok ->
        options

      {:error, reason} ->
        raise ArgumentError, "governed Gemini launch rejected: #{inspect(reason)}"
    end
  end

  @spec validate_command_options(keyword()) :: :ok | {:error, term()}
  def validate_command_options(opts) when is_list(opts) do
    with {:ok, authority} <- authority(opts) do
      validate_command_options(opts, authority)
    end
  end

  @spec invocation([String.t()], Options.t() | keyword()) :: {:ok, Command.t()} | {:error, term()}
  def invocation(args, input) when is_list(args) do
    with {:ok, %GovernedAuthority{} = authority} <- authority(input),
         :ok <- validate_invocation_input(input) do
      {:ok,
       Command.new(
         GovernedAuthority.command_spec(authority),
         args,
         GovernedAuthority.launch_options(authority)
       )}
    end
  end

  @spec run_options(keyword(), Options.t() | keyword()) :: keyword()
  def run_options(opts, input) when is_list(opts) do
    case authority(input) do
      {:ok, %GovernedAuthority{} = authority} -> Keyword.put(opts, :governed_authority, authority)
      _ -> opts
    end
  end

  defp validate_options(_options, nil), do: :ok

  defp validate_options(%Options{} = options, %GovernedAuthority{}) do
    cond do
      field = first_present_option_field(options, @option_smuggling_fields) ->
        {:error, {:governed_launch_smuggling, field}}

      model_payload_env_overrides?(options.model_payload) ->
        {:error, {:governed_launch_smuggling, :model_payload, :env_overrides}}

      true ->
        :ok
    end
  end

  defp validate_command_options(_opts, nil), do: :ok

  defp validate_command_options(opts, %GovernedAuthority{}) do
    cond do
      key = first_present_keyword(opts, @command_smuggling_fields) ->
        {:error, {:governed_launch_smuggling, key}}

      model_payload_env_overrides?(Keyword.get(opts, :model_payload)) ->
        {:error, {:governed_launch_smuggling, :model_payload, :env_overrides}}

      true ->
        :ok
    end
  end

  defp validate_invocation_input(%Options{} = options), do: validate_options(options)
  defp validate_invocation_input(opts) when is_list(opts), do: validate_command_options(opts)

  defp first_present_option_field(options, fields) do
    Enum.find(fields, fn field -> present_option_value?(field, Map.get(options, field)) end)
  end

  defp present_option_value?(:execution_surface, %ExecutionSurface{} = surface),
    do: surface != %ExecutionSurface{}

  defp present_option_value?(_field, value), do: present?(value)

  defp first_present_keyword(opts, fields) do
    Enum.find(fields, fn field ->
      Keyword.has_key?(opts, field) and present_keyword_value?(field, Keyword.get(opts, field))
    end)
  end

  defp present_keyword_value?(:execution_surface, %ExecutionSurface{} = surface),
    do: surface != %ExecutionSurface{}

  defp present_keyword_value?(_field, value), do: present?(value)

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?([]), do: false
  defp present?(%{} = value), do: map_size(value) > 0
  defp present?(_value), do: true

  defp model_payload_env_overrides?(payload) when is_map(payload) do
    case payload_value(payload, :env_overrides) do
      %{} = env -> map_size(env) > 0
      _ -> false
    end
  end

  defp model_payload_env_overrides?(_payload), do: false

  defp payload_value(payload, key) when is_map(payload) do
    Map.get(payload, key, Map.get(payload, Atom.to_string(key)))
  end
end
