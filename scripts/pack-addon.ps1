<#
.SYNOPSIS
  Pack one addon bundle into the release zip and (optionally) point registry.json at it.

.DESCRIPTION
  This is the packer behind every published addon. It reproduces EXACTLY what
  `aefos install <slug>` expects to download:

      <slug>/addon.json
      <slug>/<whatever folders the bundle carries>
      <slug>/tools/...            (only when -Binaries is given)

  The bundle folder under addons/<type>/<slug>/ is the source of truth for the
  text; binaries are NOT versioned in git (a compiled exe does not belong in a
  catalogue repo), so an addon that ships one takes it from -Binaries at pack
  time. Everything else - the version, the zip name, the sha256, the registry
  entry - is derived, never typed by hand.

  The sha256 it prints is the addon's identity: the CLI verifies it on install
  and compares it on update. Publish the zip as a release asset, and the tag
  must be <slug>-<version> so the URL below resolves.

.PARAMETER Slug
  The addon slug - the folder name under addons/<type>/.

.PARAMETER Binaries
  Optional folder whose files are laid under <slug>/tools/ in the zip. Use it
  for mcp/tool addons that ship a compiled artifact.

.PARAMETER UpdateRegistry
  Rewrite this slug's entry in registry.json (version, url, sha256) to match
  what was just packed.

.EXAMPLE
  pwsh -File scripts\pack-addon.ps1 -Slug janus-orm

.EXAMPLE
  pwsh -File scripts\pack-addon.ps1 -Slug desktop -Binaries "$env:USERPROFILE\.aefos\addons\desktop\tools" -UpdateRegistry
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string] $Slug,

  [string] $Binaries,

  [switch] $UpdateRegistry
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Owner    = 'ModernDelphiWorks/Aefos-Addons'

function Write-Step([string] $Message) {
  Write-Host "==> $Message" -ForegroundColor Cyan
}

# --- locate the bundle -------------------------------------------------------
$Bundle = Get-ChildItem -Path (Join-Path $RepoRoot 'addons') -Directory |
          ForEach-Object { Join-Path $_.FullName $Slug } |
          Where-Object { Test-Path (Join-Path $_ 'addon.json') }

if (-not $Bundle) {
  throw "No bundle found for slug '$Slug' (looked for addons/<type>/$Slug/addon.json)."
}
if ($Bundle -is [array]) {
  throw "Slug '$Slug' exists under more than one type: $($Bundle -join ', '). A slug must be unique."
}

$Manifest = Get-Content -Path (Join-Path $Bundle 'addon.json') -Raw | ConvertFrom-Json
$Version  = $Manifest.version
$Type     = Split-Path -Leaf (Split-Path -Parent $Bundle)

if ([string]::IsNullOrWhiteSpace($Version)) {
  throw "addon.json for '$Slug' has no version."
}
if ($Manifest.slug -ne $Slug) {
  throw "addon.json says slug '$($Manifest.slug)' but it lives in a folder named '$Slug'."
}

Write-Step "$Slug $Version (type: $Type)"

# --- stage -------------------------------------------------------------------
$Staging = Join-Path ([System.IO.Path]::GetTempPath()) ("aefos-pack-" + [System.Guid]::NewGuid().ToString('N'))
$Payload = Join-Path $Staging $Slug
New-Item -ItemType Directory -Path $Payload -Force | Out-Null

Copy-Item -Path (Join-Path $Bundle '*') -Destination $Payload -Recurse -Force

if ($Binaries) {
  if (-not (Test-Path $Binaries)) {
    throw "Binaries folder not found: $Binaries"
  }
  $Tools = Join-Path $Payload 'tools'
  New-Item -ItemType Directory -Path $Tools -Force | Out-Null
  Copy-Item -Path (Join-Path $Binaries '*') -Destination $Tools -Recurse -Force
  Write-Step "bundled binaries from $Binaries"
}

# --- zip ---------------------------------------------------------------------
$DistDir = Join-Path $RepoRoot 'dist'
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

$ZipName = "$Slug-$Version.zip"
$ZipPath = Join-Path $DistDir $ZipName
if (Test-Path $ZipPath) { Remove-Item -Path $ZipPath -Force }

Compress-Archive -Path $Payload -DestinationPath $ZipPath -CompressionLevel Optimal
Remove-Item -Path $Staging -Recurse -Force

$Sha = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$Url = "https://github.com/$Owner/releases/download/$Slug-$Version/$ZipName"

Write-Host ''
Write-Host "  zip     $ZipPath"
Write-Host "  size    $([math]::Round((Get-Item $ZipPath).Length / 1KB, 1)) KB"
Write-Host "  sha256  $Sha"
Write-Host "  url     $Url"
Write-Host ''

# --- registry ----------------------------------------------------------------
if ($UpdateRegistry) {
  $RegistryPath = Join-Path $RepoRoot 'registry.json'
  $Registry     = Get-Content -Path $RegistryPath -Raw | ConvertFrom-Json

  $Entry = $Registry.addons | Where-Object { $_.slug -eq $Slug }
  if (-not $Entry) {
    throw "registry.json has no entry for '$Slug'. Add it once by hand, then this script keeps it current."
  }

  $Entry.version     = $Version
  $Entry.name        = $Manifest.name
  $Entry.description = $Manifest.description
  $Entry.type        = $Type
  $Entry.trust       = $Manifest.trust
  $Entry.url         = $Url
  $Entry.sha256      = $Sha

  # ConvertTo-Json escapes nothing we need escaped, but it does turn / into \/
  # on Windows PowerShell - unescape so the URLs stay readable in the diff.
  $Json = $Registry | ConvertTo-Json -Depth 10
  $Json = $Json.Replace('\/', '/')
  Set-Content -Path $RegistryPath -Value $Json -Encoding UTF8

  Write-Step "registry.json updated for $Slug $Version"
}

Write-Step 'Next: create the release and upload the zip'
Write-Host "  gh release create $Slug-$Version `"$ZipPath`" --repo $Owner --title `"$($Manifest.name) $Version`" --notes-file <notes.md>"
