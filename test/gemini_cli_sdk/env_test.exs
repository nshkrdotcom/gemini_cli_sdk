defmodule GeminiCliSdk.EnvTest do
  use ExUnit.Case, async: false

  alias GeminiCliSdk.Env
  alias GeminiCliSdk.TestSupport

  describe "build_cli_env/1" do
    test "includes SDK version tag" do
      env = Env.build_cli_env(%{})
      assert Map.has_key?(env, "GEMINI_CLI_SDK_VERSION")
      assert env["GEMINI_CLI_SDK_VERSION"] =~ "elixir-"
    end

    test "merges user-provided env vars" do
      env = Env.build_cli_env(%{"GEMINI_API_KEY" => "test-key"})
      assert env["GEMINI_API_KEY"] == "test-key"
      assert Map.has_key?(env, "GEMINI_CLI_SDK_VERSION")
    end

    test "includes base system env vars" do
      TestSupport.with_env(%{"PATH" => "/usr/bin:/bin", "HOME" => "/home/test"}, fn ->
        env = Env.build_cli_env(%{})
        assert env["PATH"] == "/usr/bin:/bin"
        assert env["HOME"] == "/home/test"
      end)
    end

    test "passes through GEMINI_ prefixed env vars" do
      TestSupport.with_env(
        %{
          "GEMINI_API_KEY" => "key123",
          "GEMINI_CLI_HOME" => "/custom/home",
          "GEMINI_MODEL" => "flash"
        },
        fn ->
          env = Env.build_cli_env(%{})
          assert env["GEMINI_API_KEY"] == "key123"
          assert env["GEMINI_CLI_HOME"] == "/custom/home"
          assert env["GEMINI_MODEL"] == "flash"
        end
      )
    end

    test "passes through GOOGLE_ prefixed env vars" do
      TestSupport.with_env(
        %{
          "GOOGLE_CLOUD_PROJECT" => "my-project",
          "GOOGLE_CLOUD_LOCATION" => "us-central1",
          "GOOGLE_API_KEY" => "gkey"
        },
        fn ->
          env = Env.build_cli_env(%{})
          assert env["GOOGLE_CLOUD_PROJECT"] == "my-project"
          assert env["GOOGLE_CLOUD_LOCATION"] == "us-central1"
          assert env["GOOGLE_API_KEY"] == "gkey"
        end
      )
    end

    test "sets NO_COLOR=1 by default" do
      env = Env.build_cli_env(%{})
      assert env["NO_COLOR"] == "1"
    end

    test "user overrides take precedence over system env" do
      TestSupport.with_env(%{"GEMINI_API_KEY" => "system-key"}, fn ->
        env = Env.build_cli_env(%{"GEMINI_API_KEY" => "override-key"})
        assert env["GEMINI_API_KEY"] == "override-key"
      end)
    end

    test "does not include arbitrary system env vars" do
      TestSupport.with_env(%{"MY_CUSTOM_SECRET" => "secret123"}, fn ->
        env = Env.build_cli_env(%{})
        refute Map.has_key?(env, "MY_CUSTOM_SECRET")
      end)
    end
  end

  describe "normalize_overrides/1" do
    test "drops nil values" do
      assert Env.normalize_overrides(%{"KEY_A" => "one", "KEY_B" => nil}) ==
               %{"KEY_A" => "one"}
    end

    test "converts atom keys to strings" do
      assert Env.normalize_overrides(%{my_key: "val"}) ==
               %{"my_key" => "val"}
    end

    test "returns empty map for nil input" do
      assert Env.normalize_overrides(nil) == %{}
    end
  end

  describe "sdk_version_tag/0" do
    test "returns version string with elixir prefix" do
      tag = Env.sdk_version_tag()
      assert tag =~ ~r/^elixir-\d+\.\d+\.\d+/
    end
  end
end
