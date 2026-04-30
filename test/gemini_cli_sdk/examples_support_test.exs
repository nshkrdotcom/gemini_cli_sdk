defmodule GeminiCliSdk.ExamplesSupportTest do
  use ExUnit.Case, async: true

  alias CliSubprocessCore.ExecutionSurface
  alias GeminiCliSdk.ExamplesSupport

  test "parse_argv/1 keeps local defaults when ssh flags are absent" do
    assert {:ok, context} = ExamplesSupport.parse_argv(["--", "Explain", "OTP"])

    assert context.argv == ["Explain", "OTP"]
    assert context.execution_surface == nil
  end

  test "parse_argv/1 builds ssh execution_surface from shared flags" do
    assert {:ok, context} =
             ExamplesSupport.parse_argv([
               "--cwd",
               "/srv/gemini",
               "--cli-command",
               "/opt/gemini",
               "--danger-full-access",
               "--ssh-host",
               "builder@example.internal",
               "--ssh-port",
               "2222",
               "--ssh-identity-file",
               "./tmp/id_ed25519",
               "Explain",
               "OTP"
             ])

    assert %ExecutionSurface{} = context.execution_surface
    assert context.argv == ["Explain", "OTP"]
    assert context.execution_surface.surface_kind == :ssh_exec
    assert context.execution_surface.transport_options[:destination] == "example.internal"
    assert context.execution_surface.transport_options[:ssh_user] == "builder"
    assert context.execution_surface.transport_options[:port] == 2222
    assert context.execution_surface.transport_options[:identity_file] =~ "/tmp/id_ed25519"
    assert context.cli_command == "/opt/gemini"
    assert context.example_cwd == "/srv/gemini"
    assert context.example_danger_full_access == true
  end

  test "parse_argv/1 rejects orphan ssh flags without --ssh-host" do
    assert {:error, message} = ExamplesSupport.parse_argv(["--ssh-user", "builder"])
    assert message =~ "require --ssh-host"
  end

  test "parse_argv/1 rejects blank cwd values" do
    assert {:error, message} = ExamplesSupport.parse_argv(["--cwd", "   "])
    assert message =~ "--cwd"
  end

  test "with_execution_surface/1 injects the parsed surface into options structs" do
    assert {:ok, context} =
             ExamplesSupport.parse_argv([
               "--cwd",
               "/srv/gemini",
               "--cli-command",
               "/opt/gemini",
               "--danger-full-access",
               "--ssh-host",
               "example.internal"
             ])

    Process.put({ExamplesSupport, :ssh_context}, context)

    opts =
      %GeminiCliSdk.Options{model: GeminiCliSdk.Models.fast_model()}
      |> ExamplesSupport.with_execution_surface()

    assert opts.execution_surface.surface_kind == :ssh_exec
    assert opts.execution_surface.transport_options[:destination] == "example.internal"
    assert opts.cli_command == "/opt/gemini"
    assert opts.cwd == "/srv/gemini"
    assert opts.approval_mode == :yolo
    assert opts.yolo == false
    assert opts.sandbox == false
  after
    Process.delete({ExamplesSupport, :ssh_context})
  end

  test "command_opts/1 injects shared runtime flags for direct command helpers" do
    assert {:ok, context} =
             ExamplesSupport.parse_argv([
               "--cwd",
               "/srv/gemini",
               "--cli-command",
               "/opt/gemini",
               "--danger-full-access",
               "--ssh-host",
               "example.internal"
             ])

    Process.put({ExamplesSupport, :ssh_context}, context)

    opts = ExamplesSupport.command_opts([])

    assert opts[:execution_surface].surface_kind == :ssh_exec
    assert opts[:cli_command] == "/opt/gemini"
    assert opts[:cwd] == "/srv/gemini"
    assert opts[:approval_mode] == :yolo
    assert opts[:yolo] == false
    assert opts[:sandbox] == false
  after
    Process.delete({ExamplesSupport, :ssh_context})
  end
end
