# Generates the film's narration with the Windows built-in voice (no installs).
# One WAV per line; each line is read at the slowest rate that still ends
# before the next line starts. Writes clips + clips.json to $OutDir.
param([string]$OutDir = "$PSScriptRoot\.work\vo", [string]$Voice = "Microsoft David Desktop")

Add-Type -AssemblyName System.Speech
New-Item -ItemType Directory -Force $OutDir | Out-Null

# Elan, said "ay-LAHN" (IPA written as XML character codes: Windows PowerShell 5.1 reads this file as ANSI)
$E = '<phoneme alphabet="ipa" ph="e&#x26A;&#x2C8;l&#x251;&#x2D0;n">&#xC9;lan</phoneme>'
# [film time (s), window (s), SSML body]
$lines = @(
  @(0.5,  3.6, "Every time a heart loses its rhythm, <break time='250ms'/> minutes"),
  @(4.1,  2.9, "begin to matter more than <emphasis>anything</emphasis>."),
  @(7.3,  7.2, "Most people lose them, calling hospitals, <break time='300ms'/> one, <break time='120ms'/> by one."),
  @(14.9, 5.4, "$E. French for momentum. <break time='200ms'/> It turns minutes into action."),
  @(20.6, 5.9, "Hold one button, <break time='200ms'/> for one and a half seconds."),
  @(26.8, 5.3, "Holding, not tapping. <break time='150ms'/> So a pocket can never send one by accident."),
  @(32.4, 3.4, "Your location. Your symptoms. A message"),
  @(35.8, 5.5, "reach the three nearest hospitals."),
  @(41.6, 6.1, "All at the same time."),
  @(48.0, 6.3, "On the other side, the hospital's duty desk sees it, <break time='250ms'/> instantly."),
  @(54.6, 6.1, "Unanswered alerts rise to the top. <break time='200ms'/> After two minutes, the clock turns red."),
  @(61.0, 5.7, "One tap. <break time='500ms'/> Accepted."),
  @(67.0, 8.1, "Back on the patient's phone, the screen changes by itself. <break time='400ms'/> Help is on the way."),
  @(75.4, 6.1, "No refreshing. No waiting on hold. <break time='250ms'/> Just, a countdown."),
  @(81.8, 7.1, "$E never guesses. <break time='200ms'/> No G P S fix? It says so. <break time='150ms'/> No signal? It tells you the alert was not sent."),
  @(89.2, 6.1, "And it never replaces one, one, two. <break time='300ms'/> Call them first. $E works alongside."),
  @(95.6, 6.1, "Sending an alert is free. <break time='250ms'/> No payment screen, in a crisis."),
  @(102.2, 6.1, "The next time a blue dot appears on a hospital's screen,"),
  @(108.6, 6.1, "you're not looking at a location. <break time='300ms'/> You're looking at a heartbeat."),
  @(116.2, 6.0, "$E. <break time='300ms'/> Emergency cardiac care. <break time='900ms'/> Every second counts.")
)

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice($Voice)
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(48000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$out = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  $t, $win, $body = $lines[$i]
  $file = Join-Path $OutDir ("line_{0:D2}.wav" -f $i)
  foreach ($rate in -1, 0, 1, 2, 3) {
    $ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><prosody pitch='-2st'>$body</prosody></speak>"
    $synth.Rate = $rate
    $synth.SetOutputToWaveFile($file, $fmt)
    $synth.SpeakSsml($ssml)
    $synth.SetOutputToNull()
    $dur = ((Get-Item $file).Length - 44) / (48000 * 2)
    if ($dur -le $win - 0.2) { break }
  }
  $out += [pscustomobject]@{ t = $t; window = $win; rate = $rate; dur = [math]::Round($dur, 2); file = $file }
}
$synth.Dispose()
$out | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $OutDir "clips.json")
$out | Format-Table t, window, rate, dur -AutoSize | Out-String
