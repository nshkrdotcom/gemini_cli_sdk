defmodule GeminiCliSdk.OptionsTest do
  use ExUnit.Case, async: true

  alias CliSubprocessCore.ExecutionSurface
  alias GeminiCliSdk.{Configuration, Models, Options}

  describe "struct defaults" do
    test "has sensible defaults" do
      opts = %Options{}
      assert opts.execution_surface == %ExecutionSurface{}
      assert opts.model == nil
      assert opts.yolo == false
      assert opts.approval_mode == nil
      assert opts.sandbox == false
      assert opts.resume == nil
      assert opts.extensions == []
      assert opts.include_directories == []
      assert opts.allowed_tools == []
      assert opts.allowed_mcp_server_names == []
      assert opts.debug == false
      assert opts.output_format == "stream-json"
      assert opts.cwd == nil
      assert opts.env == %{}
      assert opts.settings == nil
      assert opts.system_prompt == nil
      assert opts.timeout_ms == Configuration.default_timeout_ms()
    end
  end

  describe "validate!/1" do
    test "resolves and validates model payload when valid" do
      opts = %Options{model: Models.fast_model()}
      validated = Options.validate!(opts)

      assert validated.model == Models.fast_model()
      assert validated.model_payload.resolved_model == Models.fast_model()
    end

    test "raises when yolo and approval_mode are both set" do
      opts = %Options{yolo: true, approval_mode: :yolo}

      assert_raise ArgumentError, ~r/Cannot set both/, fn ->
        Options.validate!(opts)
      end
    end

    test "raises for invalid approval_mode" do
      opts = %Options{approval_mode: :invalid_mode}

      assert_raise ArgumentError, ~r/Invalid approval_mode/, fn ->
        Options.validate!(opts)
      end
    end

    test "allows valid approval_modes" do
      for mode <- [:default, :auto_edit, :yolo, :plan] do
        opts = %Options{approval_mode: mode}
        validated = Options.validate!(opts)

        assert validated.approval_mode == mode
        assert validated.model == Models.default_model()
        assert validated.model_payload.resolved_model == Models.default_model()
      end
    end

    test "normalizes approval_mode string aliases through schema-backed parsing" do
      validated = Options.validate!(%Options{approval_mode: "auto-edit"})

      assert validated.approval_mode == :auto_edit
      assert validated.model == Models.default_model()
    end

    test "raises when include_directories exceeds 5" do
      opts = %Options{include_directories: Enum.map(1..6, &"dir#{&1}")}

      assert_raise ArgumentError, ~r/Maximum #{Configuration.max_include_directories()}/, fn ->
        Options.validate!(opts)
      end
    end

    test "allows up to 5 include_directories" do
      opts = %Options{include_directories: Enum.map(1..5, &"dir#{&1}")}
      validated = Options.validate!(opts)

      assert validated.include_directories == opts.include_directories
      assert validated.model == Models.default_model()
    end

    test "raises when timeout_ms is not positive" do
      opts = %Options{timeout_ms: 0}

      assert_raise ArgumentError, ~r/timeout_ms must be positive/, fn ->
        Options.validate!(opts)
      end
    end

    test "raises when timeout_ms is negative" do
      opts = %Options{timeout_ms: -1}

      assert_raise ArgumentError, ~r/timeout_ms must be positive/, fn ->
        Options.validate!(opts)
      end
    end

    test "raises when allowed_tools is not a string list" do
      assert_raise ArgumentError, ~r/allowed_tools/, fn ->
        Options.validate!(%Options{allowed_tools: :read_file})
      end
    end

    test "treats an explicit model_payload as authoritative" do
      {:ok, payload} =
        CliSubprocessCore.ModelRegistry.build_arg_payload(:gemini, Models.fast_model(), [])

      opts = %Options{model_payload: payload, model: Models.fast_model()}
      validated = Options.validate!(opts)

      assert validated.model_payload == payload
      assert validated.model == Models.fast_model()
    end

    test "does not treat GEMINI_MODEL env defaults as active config when payload is explicit" do
      {:ok, payload} =
        CliSubprocessCore.ModelRegistry.build_arg_payload(:gemini, Models.fast_model(), [])

      validated =
        Options.validate!(%Options{
          model_payload: payload,
          env: %{"GEMINI_MODEL" => Models.default_model()}
        })

      assert validated.model_payload == payload
      assert validated.model == Models.fast_model()
    end

    test "raises when raw model conflicts with an explicit model_payload" do
      {:ok, payload} =
        CliSubprocessCore.ModelRegistry.build_arg_payload(:gemini, Models.fast_model(), [])

      assert_raise ArgumentError, ~r/model_payload_conflict/, fn ->
        Options.validate!(%Options{model_payload: payload, model: Models.default_model()})
      end
    end

    test "normalizes execution_surface from provider-facing keyword input" do
      validated =
        Options.validate!(%Options{
          execution_surface: [
            surface_kind: :ssh_exec,
            transport_options: [destination: "gemini-options.test.example", port: 2222],
            target_id: "target-1"
          ]
        })

      assert %ExecutionSurface{} = validated.execution_surface
      assert validated.execution_surface.surface_kind == :ssh_exec

      assert validated.execution_surface.transport_options == [
               destination: "gemini-options.test.example",
               port: 2222
             ]

      assert validated.execution_surface.target_id == "target-1"
    end
  end
end
