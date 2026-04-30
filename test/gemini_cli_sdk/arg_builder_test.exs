defmodule GeminiCliSdk.ArgBuilderTest do
  use ExUnit.Case, async: true

  alias GeminiCliSdk.{ArgBuilder, Models, Options}

  describe "build_args/2" do
    test "default options produce output-format stream-json" do
      args = ArgBuilder.build_args(%Options{})
      assert "--output-format" in args
      idx = Enum.find_index(args, &(&1 == "--output-format"))
      assert Enum.at(args, idx + 1) == "stream-json"
    end

    test "includes --prompt flag with actual prompt text" do
      args = ArgBuilder.build_args(%Options{}, "hello world")
      idx = Enum.find_index(args, &(&1 == "--prompt"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == "hello world"
    end

    test "omits --prompt flag when prompt is nil" do
      args = ArgBuilder.build_args(%Options{})
      refute "--prompt" in args
    end

    test "includes --model flag" do
      args = ArgBuilder.build_args(%Options{model: Models.fast_model()})
      idx = Enum.find_index(args, &(&1 == "--model"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == Models.fast_model()
    end

    test "omits --model when nil" do
      args = ArgBuilder.build_args(%Options{model: nil})
      refute "--model" in args
    end

    test "includes --approval-mode flag" do
      args = ArgBuilder.build_args(%Options{approval_mode: :auto_edit})
      idx = Enum.find_index(args, &(&1 == "--approval-mode"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == "auto_edit"
    end

    test "omits --approval-mode when nil" do
      args = ArgBuilder.build_args(%Options{approval_mode: nil})
      refute "--approval-mode" in args
    end

    test "includes --yolo flag when yolo is true and no approval_mode" do
      args = ArgBuilder.build_args(%Options{yolo: true, approval_mode: nil})
      assert "--yolo" in args
    end

    test "omits --yolo when approval_mode is set" do
      args = ArgBuilder.build_args(%Options{yolo: true, approval_mode: :yolo})
      refute "--yolo" in args
    end

    test "omits --yolo when yolo is false" do
      args = ArgBuilder.build_args(%Options{yolo: false})
      refute "--yolo" in args
    end

    test "includes --sandbox flag" do
      args = ArgBuilder.build_args(%Options{sandbox: true})
      assert "--sandbox" in args
    end

    test "omits --sandbox when false" do
      args = ArgBuilder.build_args(%Options{sandbox: false})
      refute "--sandbox" in args
    end

    test "includes --skip-trust when true" do
      args = ArgBuilder.build_args(%Options{skip_trust: true})
      assert "--skip-trust" in args
    end

    test "omits --skip-trust when false" do
      args = ArgBuilder.build_args(%Options{skip_trust: false})
      refute "--skip-trust" in args
    end

    test "includes --resume with no value for true" do
      args = ArgBuilder.build_args(%Options{resume: true})
      assert "--resume" in args
      idx = Enum.find_index(args, &(&1 == "--resume"))
      # Next arg should not be a value (it's the next flag or end of list)
      next = Enum.at(args, idx + 1)
      assert next == nil or String.starts_with?(next, "--")
    end

    test "includes --resume with value for string" do
      args = ArgBuilder.build_args(%Options{resume: "abc123"})
      idx = Enum.find_index(args, &(&1 == "--resume"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == "abc123"
    end

    test "includes --resume for 'latest'" do
      args = ArgBuilder.build_args(%Options{resume: "latest"})
      assert "--resume" in args
    end

    test "omits --resume when nil" do
      args = ArgBuilder.build_args(%Options{resume: nil})
      refute "--resume" in args
    end

    test "includes --extensions for each extension" do
      args = ArgBuilder.build_args(%Options{extensions: ["ext1", "ext2"]})
      # Each extension gets its own --extensions flag
      ext_indices =
        Enum.with_index(args)
        |> Enum.filter(fn {v, _} -> v == "--extensions" end)
        |> Enum.map(fn {_, i} -> i end)

      assert length(ext_indices) == 2
      values = Enum.map(ext_indices, &Enum.at(args, &1 + 1))
      assert "ext1" in values
      assert "ext2" in values
    end

    test "omits --extensions when empty" do
      args = ArgBuilder.build_args(%Options{extensions: []})
      refute "--extensions" in args
    end

    test "includes --include-directories as comma-separated" do
      args = ArgBuilder.build_args(%Options{include_directories: ["src", "docs"]})
      idx = Enum.find_index(args, &(&1 == "--include-directories"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == "src,docs"
    end

    test "includes --allowed-tools as comma-separated" do
      args = ArgBuilder.build_args(%Options{allowed_tools: ["Bash", "Read"]})
      idx = Enum.find_index(args, &(&1 == "--allowed-tools"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == "Bash,Read"
    end

    test "includes --allowed-mcp-server-names as comma-separated" do
      args = ArgBuilder.build_args(%Options{allowed_mcp_server_names: ["github", "jira"]})
      idx = Enum.find_index(args, &(&1 == "--allowed-mcp-server-names"))
      assert idx != nil
      assert Enum.at(args, idx + 1) == "github,jira"
    end

    test "includes --debug flag" do
      args = ArgBuilder.build_args(%Options{debug: true})
      assert "--debug" in args
    end

    test "omits --debug when false" do
      args = ArgBuilder.build_args(%Options{debug: false})
      refute "--debug" in args
    end

    test "combines multiple flags" do
      args =
        ArgBuilder.build_args(
          %Options{
            model: Models.default_model(),
            sandbox: true,
            debug: true,
            yolo: true
          },
          "test prompt"
        )

      assert "--prompt" in args
      assert "--model" in args
      assert "--sandbox" in args
      assert "--debug" in args
      assert "--yolo" in args
      assert "--output-format" in args
    end
  end
end
