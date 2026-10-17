# Nunki's voice on Windows. Run by Nunki.Voice.Windows with Windows
# PowerShell 5.1:
#
#   powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File windows.ps1 -Action list
#   powershell.exe ... -File windows.ps1 -Action speak -TextFile <file> -Lang nl [-Voice <name>]
#
# list:  one voice a line, "name<TAB>language<TAB>engine", engine being
#        winrt (the OneCore voices, where the Dutch speech pack puts its
#        voice) or sapi (System.Speech, the older desktop voices).
# speak: reads the UTF-8 text in -TextFile aloud and returns when it is
#        done. WinRT first: synthesised to a WAV beside the text file and
#        played with SoundPlayer.PlaySync(); SAPI when WinRT is not there.
#        -Voice names the voice; without it, the first voice for -Lang;
#        without that, the system's default.
#
# The text comes from a file and only from a file: nothing said is ever
# part of a command line. This file is ASCII on purpose - Windows
# PowerShell 5.1 reads a script without a byte order mark in the system's
# code page.

param(
    [ValidateSet("list", "speak")][string]$Action = "list",
    [string]$TextFile = "",
    [string]$Lang = "en",
    [string]$Voice = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- WinRT ---------------------------------------------------------------------

$script:WinRT = $false

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    $script:AsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq "AsTask" -and $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1"
        } |
        Select-Object -First 1
    if ($script:AsTask) { $script:WinRT = $true }
} catch {
    $script:WinRT = $false
}

function Wait-WinRT($Operation, [Type]$ResultType) {
    $task = $script:AsTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $null = $task.Wait(-1)
    return $task.Result
}

function Get-WinRTVoices {
    if (-not $script:WinRT) { return @() }
    try {
        return @([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices)
    } catch {
        return @()
    }
}

# --- SAPI ----------------------------------------------------------------------

$script:Sapi = $false

try {
    Add-Type -AssemblyName System.Speech
    $script:Sapi = $true
} catch {
    $script:Sapi = $false
}

function Get-SapiVoices {
    if (-not $script:Sapi) { return @() }
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        return @($synth.GetInstalledVoices() | Where-Object { $_.Enabled } | ForEach-Object { $_.VoiceInfo })
    } finally {
        $synth.Dispose()
    }
}

# --- list ----------------------------------------------------------------------

if ($Action -eq "list") {
    foreach ($v in Get-WinRTVoices) {
        [Console]::Out.WriteLine(("{0}`t{1}`twinrt" -f $v.DisplayName, $v.Language))
    }
    foreach ($v in Get-SapiVoices) {
        [Console]::Out.WriteLine(("{0}`t{1}`tsapi" -f $v.Name, $v.Culture.Name))
    }
    exit 0
}

# --- speak ---------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $TextFile)) {
    [Console]::Error.WriteLine("No text file: $TextFile")
    exit 2
}

$text = [System.IO.File]::ReadAllText($TextFile, [System.Text.Encoding]::UTF8)

function Find-Voice($Voices, [string]$NameOf, [string]$LanguageOf) {
    if ($Voice -ne "") {
        $named = $Voices | Where-Object { $_.$NameOf -eq $Voice } | Select-Object -First 1
        if ($named) { return $named }
    }
    return $Voices | Where-Object { ([string]$_.$LanguageOf).ToLower().StartsWith($Lang.ToLower()) } |
        Select-Object -First 1
}

function Speak-WinRT {
    $voices = Get-WinRTVoices
    if ($voices.Count -eq 0) { return $false }

    $synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
    $chosen = Find-Voice $voices "DisplayName" "Language"
    if ($chosen) { $synth.Voice = $chosen }

    $stream = Wait-WinRT ($synth.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
    $wav = [System.IO.Path]::ChangeExtension($TextFile, ".wav")

    try {
        $source = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
        $output = [System.IO.File]::Create($wav)
        try { $source.CopyTo($output) } finally { $output.Dispose(); $source.Dispose() }

        $player = New-Object System.Media.SoundPlayer $wav
        try { $player.PlaySync() } finally { $player.Dispose() }
    } finally {
        $stream.Dispose()
        $synth.Dispose()
        Remove-Item -LiteralPath $wav -ErrorAction SilentlyContinue
    }
    return $true
}

function Speak-Sapi {
    if (-not $script:Sapi) { return $false }
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try {
        $chosen = Find-Voice (Get-SapiVoices) "Name" "Culture"
        if ($chosen) { $synth.SelectVoice($chosen.Name) }
        $synth.SetOutputToDefaultAudioDevice()
        $synth.Speak($text)
    } finally {
        $synth.Dispose()
    }
    return $true
}

$spoken = $false

if ($script:WinRT) {
    try {
        $spoken = Speak-WinRT
    } catch {
        [Console]::Error.WriteLine("WinRT speech failed: $($_.Exception.Message)")
        $spoken = $false
    }
}

if (-not $spoken) {
    try {
        $spoken = Speak-Sapi
    } catch {
        [Console]::Error.WriteLine("SAPI speech failed: $($_.Exception.Message)")
        $spoken = $false
    }
}

if ($spoken) { exit 0 } else { exit 3 }
