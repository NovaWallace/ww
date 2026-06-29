$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$textExtensions = @(".html", ".js", ".json", ".css", ".txt", ".md", ".ps1")
$skipDirs = @(".git", ".agents")
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)

# Keep this script ASCII-only. Suspicious Chinese-mojibake probes are code points.
$suspiciousCodePoints = @(
  0xfffd, # replacement character
  0x9e26, # common mojibake start for Ming...
  0x93c8,
  0x6f8b,
  0x95ab,
  0x9479,
  0x6f8c,
  0x7e48,
  0x95ab
)

$failed = $false

Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
  $relativePath = $_.FullName.Substring($root.Length).TrimStart("\", "/")
  $topDir = ($relativePath -split "[\\/]", 2)[0]
  $textExtensions -contains $_.Extension.ToLowerInvariant() -and
  -not ($skipDirs -contains $topDir)
} | ForEach-Object {
  $path = $_.FullName
  $relative = Resolve-Path -LiteralPath $path -Relative
  $bytes = [System.IO.File]::ReadAllBytes($path)

  try {
    $text = $utf8Strict.GetString($bytes)
  } catch {
    Write-Host "UTF8_BAD $relative" -ForegroundColor Red
    $script:failed = $true
    return
  }

  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
    Write-Host "UTF8_BOM $relative" -ForegroundColor Yellow
  }

  foreach ($codePoint in $suspiciousCodePoints) {
    $pattern = [char]$codePoint
    if ($text.Contains($pattern)) {
      Write-Host ("SUSPICIOUS_TEXT {0} U+{1:X4}" -f $relative, $codePoint) -ForegroundColor Yellow
      $script:failed = $true
      break
    }
  }

  Write-Host "UTF8_OK $relative"
}

if ($failed) {
  exit 1
}
