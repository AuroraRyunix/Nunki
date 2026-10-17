defmodule Nunki.LauncherDetails.Stats do
  @moduledoc """
  What `GET /_launcher/stats` answers: the JSON documented in
  `docs/launcher-details.md`. Raw numbers for anything that wants to compute,
  and `summary` - the same numbers as label/value lines in words and units,
  English or Dutch - for anything that only wants to show them (the Windows
  launcher, `nunki.sh details`).

  Cheap by rule, because it is asked every two seconds for as long as
  somebody leaves a panel open: nothing here runs a program (the voice is
  the one last looked up, not asked for again), no process is asked
  anything it could be slow to answer, and nothing waits.
  """

  alias Nunki.LauncherDetails

  @mb 1_048_576

  @doc "The whole answer, as a map ready for JSON. `lang` is \"en\" or \"nl\"."
  def collect(lang \\ "en") do
    lang = if lang == "nl", do: "nl", else: "en"
    memory = :erlang.memory()
    uptime_ms = :erlang.statistics(:wall_clock) |> elem(0)

    stats = %{
      app: "nunki",
      version: Nunki.version(),
      uptime_s: div(uptime_ms, 1000),
      started_at:
        DateTime.utc_now(:second) |> DateTime.add(-div(uptime_ms, 1000)) |> DateTime.to_iso8601(),
      system: system(),
      beam: %{
        memory_bytes: %{
          total: memory[:total],
          processes: memory[:processes],
          ets: memory[:ets],
          binary: memory[:binary],
          code: memory[:code]
        },
        processes: :erlang.system_info(:process_count),
        schedulers: :erlang.system_info(:schedulers_online),
        run_queue: :erlang.statistics(:run_queue),
        cpu_percent: LauncherDetails.cpu_percent()
      },
      state: state_file(),
      log: log(),
      nunki: %{
        live_views: live_views(),
        tournaments: safe(fn -> length(Nunki.Store.tournaments()) end),
        links_up: safe(&Nunki.Tournaments.links_up/0),
        voice: safe(&voice/0),
        speaking: safe(&Nunki.Speaker.speaking?/0) || false
      }
    }

    Map.put(stats, :summary, summary(stats, lang))
  end

  # --- the parts --------------------------------------------------------------

  defp system do
    {family, name} = :os.type()

    os =
      case {family, name} do
        {:win32, _} -> "windows"
        {:unix, :darwin} -> "macos"
        {:unix, other} -> to_string(other)
      end

    %{
      os: os,
      os_version: :os.version() |> Tuple.to_list() |> Enum.join("."),
      arch: to_string(:erlang.system_info(:system_architecture)),
      cores: :erlang.system_info(:logical_processors_available) |> integer_or_nil(),
      otp: to_string(:erlang.system_info(:otp_release)),
      elixir: System.version(),
      load_average: load_average()
    }
  end

  defp integer_or_nil(n) when is_integer(n), do: n
  defp integer_or_nil(_unknown), do: nil

  defp load_average do
    with {:ok, text} <- File.read("/proc/loadavg"),
         [one, five, fifteen | _] <- String.split(text),
         {one, _} <- Float.parse(one),
         {five, _} <- Float.parse(five),
         {fifteen, _} <- Float.parse(fifteen) do
      [one, five, fifteen]
    else
      _none -> nil
    end
  end

  # Where state.json is and how big. There is no database to ping.
  defp state_file do
    path = data_dir() && Path.join(data_dir(), "state.json")

    size =
      case path && File.stat(path) do
        {:ok, %{size: size}} -> size
        _none -> nil
      end

    %{path: path, size_bytes: size}
  end

  defp log do
    data = data_dir()

    cond do
      System.get_env(LauncherDetails.env_var()) not in [nil, ""] and is_binary(data) and
          File.exists?(Path.join(data, "launcher.log")) ->
        %{source: "file", path: Path.join(data, "launcher.log")}

      System.get_env("INVOCATION_ID") not in [nil, ""] ->
        %{source: "journald", unit: systemd_unit()}

      true ->
        %{source: "stdout"}
    end
  end

  defp data_dir, do: Application.get_env(:nunki, :data_dir)

  defp systemd_unit do
    with {:ok, text} <- File.read("/proc/self/cgroup"),
         [unit | _] <- Regex.run(~r/[^\/\s]+\.service/, text) do
      unit
    else
      _none -> nil
    end
  end

  defp live_views do
    Enum.count(Process.list(), fn pid ->
      match?(
        {{:dictionary, :"$initial_call"}, {_view, :mount, 3}},
        :erlang.process_info(pid, {:dictionary, :"$initial_call"})
      )
    end)
  end

  # The voice of each language, in one line: "en: Microsoft Zira (en-US);
  # nl: none". From the list looked up at start, never asked for here.
  defp voice do
    Enum.map_join(["en", "nl"], "; ", fn lang ->
      "#{lang}: #{Nunki.Voice.label(lang) || "none"}"
    end)
  end

  defp safe(fun) do
    fun.()
  rescue
    _error -> nil
  catch
    :exit, _reason -> nil
  end

  # --- in words -----------------------------------------------------------------

  @labels %{
    "en" => %{
      version: "Version",
      uptime: "Running for",
      cpu: "CPU",
      memory: "Memory",
      state: "State file",
      system: "System",
      pages: "Pages open",
      tournaments: "Tournaments",
      links: "Links up",
      voice: "Voice",
      speaking: "Speaking"
    },
    "nl" => %{
      version: "Versie",
      uptime: "Draait al",
      cpu: "Processor",
      memory: "Geheugen",
      state: "Statusbestand",
      system: "Systeem",
      pages: "Open pagina's",
      tournaments: "Toernooien",
      links: "Verbindingen",
      voice: "Stem",
      speaking: "Spreekt"
    }
  }

  @doc "The label of each summary line, in order, for a language - what a launcher shows before the server answers."
  def labels(lang \\ "en") do
    l = @labels[lang] || @labels["en"]

    [l.version, l.uptime, l.cpu, l.memory, l.state, l.system, l.pages] ++
      [l.tournaments, l.links, l.voice, l.speaking]
  end

  defp summary(s, lang) do
    l = @labels[lang]
    nl? = lang == "nl"
    beam = s.beam
    mem = beam.memory_bytes
    app = s.nunki

    cpu =
      [
        if(beam.cpu_percent, do: "#{num(beam.cpu_percent, 1, nl?)} %", else: "—"),
        "(#{beam.schedulers} schedulers, #{if nl?, do: "wachtrij", else: "run queue"} #{beam.run_queue})",
        s.system.load_average &&
          "load " <> Enum.map_join(s.system.load_average, " ", &num(&1, 2, nl?))
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    memory =
      "#{mb(mem.total, nl?)} (#{if nl?, do: "processen", else: "processes"} #{mb(mem.processes, nl?)}, " <>
        "ETS #{mb(mem.ets, nl?)}, binary #{mb(mem.binary, nl?)}; " <>
        "#{beam.processes} #{if nl?, do: "processen", else: "processes"})"

    state =
      case s.state.size_bytes do
        nil -> "—"
        bytes -> "#{num(bytes / 1024, 1, nl?)} kB"
      end

    sys = s.system

    system =
      "#{os_name(sys.os)} #{sys.os_version}, #{sys.arch}, " <>
        "#{if sys.cores, do: "#{sys.cores} #{if nl?, do: "kernen", else: "cores"}, ", else: ""}" <>
        "OTP #{sys.otp}"

    links =
      case {app.links_up, app.tournaments} do
        {nil, _} -> "—"
        {up, nil} -> to_string(up)
        {up, total} -> "#{up} #{if nl?, do: "van", else: "of"} #{total}"
      end

    [
      [l.version, "Nunki #{s.version}"],
      [l.uptime, duration(s.uptime_s)],
      [l.cpu, cpu],
      [l.memory, memory],
      [l.state, state],
      [l.system, system],
      [l.pages, to_string(app.live_views)],
      [l.tournaments, dash(app.tournaments)],
      [l.links, links],
      [l.voice, dash(app.voice)],
      [l.speaking, yes_no(app.speaking, nl?)]
    ]
    |> Enum.map(fn [label, value] -> %{label: label, value: value} end)
  end

  defp yes_no(true, nl?), do: if(nl?, do: "ja", else: "yes")
  defp yes_no(_no, nl?), do: if(nl?, do: "nee", else: "no")

  defp os_name("windows"), do: "Windows"
  defp os_name("macos"), do: "macOS"
  defp os_name("linux"), do: "Linux"
  defp os_name(other), do: other

  defp dash(nil), do: "—"
  defp dash(n), do: to_string(n)

  defp mb(nil, _nl?), do: "—"
  defp mb(bytes, nl?), do: "#{num(bytes / @mb, 1, nl?)} MB"

  defp num(value, 0, _nl?), do: value |> round() |> Integer.to_string()

  defp num(value, decimals, nl?) do
    text = :erlang.float_to_binary(value / 1, decimals: decimals)
    if nl?, do: String.replace(text, ".", ","), else: text
  end

  defp duration(seconds) do
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      days > 0 -> "#{days} d #{hours} h"
      hours > 0 -> "#{hours} h #{minutes} min"
      minutes > 0 -> "#{minutes} min"
      true -> "#{seconds} s"
    end
  end
end
