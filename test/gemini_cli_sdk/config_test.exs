defmodule GeminiCliSdk.ConfigTest do
  use ExUnit.Case, async: true

  alias GeminiCliSdk.Config
  alias GeminiCliSdk.Error

  describe "build_runtime_workspace/1" do
    test "returns nil path and temp_dir when settings is nil" do
      assert {:ok, nil, nil} = Config.build_runtime_workspace(nil)
    end

    test "creates workspace settings.json from map" do
      settings = %{
        "general" => %{"defaultApprovalMode" => "yolo"},
        "tools" => %{"allowed" => ["Bash"]}
      }

      assert {:ok, cwd, temp_dir} = Config.build_runtime_workspace(settings)
      path = Path.join([cwd, ".gemini", "settings.json"])
      assert cwd != nil
      assert temp_dir != nil
      assert File.exists?(path)

      content = path |> File.read!() |> Jason.decode!()
      assert content["general"]["defaultApprovalMode"] == "yolo"
      assert content["tools"]["allowed"] == ["Bash"]

      # Cleanup
      Config.cleanup(temp_dir)
      refute File.exists?(path)
    end

    test "creates unique temp directories" do
      settings = %{"general" => %{}}

      {:ok, _cwd1, dir1} = Config.build_runtime_workspace(settings)
      {:ok, _cwd2, dir2} = Config.build_runtime_workspace(settings)

      assert dir1 != dir2

      Config.cleanup(dir1)
      Config.cleanup(dir2)
    end

    test "handles empty settings map" do
      assert {:ok, cwd, temp_dir} = Config.build_runtime_workspace(%{})
      path = Path.join([cwd, ".gemini", "settings.json"])
      assert File.exists?(path)

      content = path |> File.read!() |> Jason.decode!()
      assert content == %{}

      Config.cleanup(temp_dir)
    end

    test "handles complex nested settings" do
      settings = %{
        "mcpServers" => %{
          "github" => %{
            "command" => "npx",
            "args" => ["-y", "@modelcontextprotocol/server-github"],
            "headers" => %{"Authorization" => "Bearer ghp_test"}
          }
        },
        "security" => %{
          "disableYoloMode" => false
        }
      }

      {:ok, cwd, temp_dir} = Config.build_runtime_workspace(settings)
      path = Path.join([cwd, ".gemini", "settings.json"])
      content = path |> File.read!() |> Jason.decode!()

      assert content["mcpServers"]["github"]["command"] == "npx"
      assert content["security"]["disableYoloMode"] == false

      Config.cleanup(temp_dir)
    end
  end

  describe "cleanup/1" do
    test "returns :ok for nil" do
      assert :ok = Config.cleanup(nil)
    end

    test "removes temp directory and contents" do
      {:ok, cwd, temp_dir} = Config.build_runtime_workspace(%{"test" => true})
      path = Path.join([cwd, ".gemini", "settings.json"])
      assert File.exists?(path)
      assert File.exists?(temp_dir)

      Config.cleanup(temp_dir)
      refute File.exists?(temp_dir)
      refute File.exists?(path)
    end

    test "returns :ok for nonexistent directory" do
      assert :ok = Config.cleanup("/tmp/nonexistent-gemini-sdk-test-dir")
    end
  end

  describe "read_settings_file/1" do
    test "reads and parses an existing settings.json" do
      dir = System.tmp_dir!() |> Path.join("gemini_sdk_config_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "settings.json")

      settings = %{"general" => %{"vimMode" => true}}
      File.write!(path, Jason.encode!(settings))

      try do
        assert {:ok, parsed} = Config.read_settings_file(path)
        assert parsed["general"]["vimMode"] == true
      after
        File.rm_rf(dir)
      end
    end

    test "returns error for nonexistent file" do
      assert {:error, %Error{kind: :config_error}} =
               Config.read_settings_file("/nonexistent/settings.json")
    end

    test "returns error for invalid JSON" do
      dir = System.tmp_dir!() |> Path.join("gemini_sdk_config_bad_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "settings.json")
      File.write!(path, "not json {{{")

      try do
        assert {:error, %Error{kind: :config_error}} = Config.read_settings_file(path)
      after
        File.rm_rf(dir)
      end
    end
  end

  describe "merge_settings/2" do
    test "merges base and overrides with deep merge" do
      base = %{
        "general" => %{"vimMode" => true, "defaultApprovalMode" => "default"},
        "model" => %{"maxSessionTurns" => 50}
      }

      overrides = %{
        "general" => %{"defaultApprovalMode" => "yolo"},
        "tools" => %{"allowed" => ["Bash"]}
      }

      merged = Config.merge_settings(base, overrides)

      assert merged["general"]["vimMode"] == true
      assert merged["general"]["defaultApprovalMode"] == "yolo"
      assert merged["model"]["maxSessionTurns"] == 50
      assert merged["tools"]["allowed"] == ["Bash"]
    end

    test "overrides replace non-map values" do
      base = %{"general" => %{"vimMode" => true}}
      overrides = %{"general" => %{"vimMode" => false}}

      merged = Config.merge_settings(base, overrides)
      assert merged["general"]["vimMode"] == false
    end
  end
end
