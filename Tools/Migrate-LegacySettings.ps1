param(
    [string]$GamePath = (Join-Path ${env:ProgramFiles(x86)} 'World of Warcraft\_forever_')
)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name Wow,WowClassic,WowClassicT,WowB -ErrorAction SilentlyContinue) {
    throw 'Close WoW before migrating saved settings. A reload is not sufficient for this one-time step.'
}
$accountRoot = Join-Path (Join-Path $GamePath 'WTF') 'Account'
if (!(Test-Path -LiteralPath $accountRoot -PathType Container)) { throw 'WoW account folder was not found. Pass -GamePath for your installation.' }
$copied = 0; $skipped = 0
foreach ($account in Get-ChildItem -LiteralPath $accountRoot -Directory) {
    $saved = Join-Path $account.FullName 'SavedVariables'
    $source = Join-Path $saved 'NokiTrading.lua'
    $target = Join-Path $saved 'MarketeerForever.lua'
    if (!(Test-Path -LiteralPath $source -PathType Leaf)) { continue }
    if (Test-Path -LiteralPath $target) { $skipped++; continue }
    # CreateNew ensures an existing new save is never overwritten, even in a race.
    $inputStream = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $outputStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $inputStream.CopyTo($outputStream); $outputStream.Flush() }
        catch { $outputStream.Dispose(); Remove-Item -LiteralPath $target -Force; throw }
        finally { $outputStream.Dispose() }
    } finally { $inputStream.Dispose() }
    $copied++
}
Write-Output "Copied settings for $copied account(s); skipped $skipped existing Marketeer save(s). Original saves remain unchanged."
