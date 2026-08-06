<#
.SYNOPSIS
  Validate the whole catalogue: every bundle, and registry.json against them.

.DESCRIPTION
  This is the gate a Pull Request has to pass. It exists because the README is a
  contract with people who do not work here: a contributor follows the checklist,
  opens a PR, and something has to actually CHECK it - otherwise the checklist is
  a wish.

  What it verifies, and why each one is here:

    * addon.json parses, and its slug matches the folder it lives in. A manifest
      that disagrees with its own path installs under the wrong name.
    * The slug is unique across every type. `aefos install <slug>` has one
      argument; two bundles answering to it is undefined behaviour.
    * The type block the manifest declares is the one on disk. A `command` that
      ships no OKF teaches the model nothing; an `mcp` with no server.json wires
      nothing.
    * OKF frontmatter follows the spec's shape - `type:` on concept files,
      `okf_version` on index.md ALONE, none on log.md / playbooks/index.md.
    * Relative markdown links resolve. A dead link in knowledge the model reads
      is worse than a dead link in prose: it silently truncates what it learns.
    * registry.json agrees with the bundles - version, type, name, description -
      and its url is the release the tag convention predicts. The registry is
      what the CLI reads; a registry that drifts from the tree ships the wrong
      thing while the tree looks right.

  It deliberately does NOT verify sha256 against a live download: the gate must
  pass offline and before the release exists. pack-addon.ps1 owns that number.

.EXAMPLE
  pwsh -File scripts\validate-catalogue.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$AddonsRoot = Join-Path $RepoRoot 'addons'
$KnownTypes = @('command', 'mcp', 'tool')
$Owner      = 'ModernDelphiWorks/Aefos-Addons'

$script:Problems = New-Object System.Collections.Generic.List[string]
$script:Checked  = 0

function Add-Problem([string] $Where, [string] $What) {
  $script:Problems.Add("$Where : $What")
}

function Test-Rule([string] $Where, [string] $What, [bool] $Ok) {
  $script:Checked++
  if (-not $Ok) { Add-Problem $Where $What }
}

function Get-Frontmatter([string] $Path) {
  # Returns $null when the file has no frontmatter block at all.
  $lines = Get-Content -Path $Path
  if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
  $body = @()
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') { return ($body -join "`n") }
    $body += $lines[$i]
  }
  return $null   # opened but never closed - treated as absent, and caught below
}

# =============================================================================
# 1. Bundles
# =============================================================================
$Bundles = @{}

foreach ($TypeDir in (Get-ChildItem -Path $AddonsRoot -Directory)) {
  $Type = $TypeDir.Name
  Test-Rule "addons/$Type" "unknown type folder (expected: $($KnownTypes -join ', '))" ($KnownTypes -contains $Type)

  foreach ($BundleDir in (Get-ChildItem -Path $TypeDir.FullName -Directory)) {
    $Slug     = $BundleDir.Name
    $Where    = "addons/$Type/$Slug"
    $ManPath  = Join-Path $BundleDir.FullName 'addon.json'

    if (-not (Test-Path $ManPath)) {
      Add-Problem $Where 'addon.json is missing (it is the only always-required file)'
      continue
    }

    try {
      $Manifest = Get-Content -Path $ManPath -Raw | ConvertFrom-Json
    } catch {
      Add-Problem "$Where/addon.json" "does not parse as JSON: $($_.Exception.Message)"
      continue
    }

    Test-Rule "$Where/addon.json" "slug is '$($Manifest.slug)' but the folder is '$Slug'" ($Manifest.slug -eq $Slug)
    Test-Rule "$Where/addon.json" 'version is missing' (-not [string]::IsNullOrWhiteSpace($Manifest.version))
    Test-Rule "$Where/addon.json" 'name is missing' (-not [string]::IsNullOrWhiteSpace($Manifest.name))
    Test-Rule "$Where/addon.json" 'description is missing' (-not [string]::IsNullOrWhiteSpace($Manifest.description))

    if ($Manifest.version) {
      Test-Rule "$Where/addon.json" "version '$($Manifest.version)' is not MAJOR.MINOR.PATCH" ($Manifest.version -match '^\d+\.\d+\.\d+$')
    }

    if ($Bundles.ContainsKey($Slug)) {
      Add-Problem $Where "slug '$Slug' is already used by $($Bundles[$Slug].Type)/$Slug - a slug must be unique across every type"
    } else {
      $Bundles[$Slug] = [pscustomobject]@{
        Slug = $Slug; Type = $Type; Path = $BundleDir.FullName; Manifest = $Manifest
      }
    }

    # --- per-type payload ---------------------------------------------------
    switch ($Type) {
      'command' {
        $CmdDir = Join-Path $BundleDir.FullName 'command'
        $Skill  = Join-Path $BundleDir.FullName 'skill/SKILL.md'
        $Okf    = Join-Path $BundleDir.FullName 'skill/okf'

        Test-Rule $Where 'command/ is missing (a command addon has no trigger without it)' (Test-Path $CmdDir)
        Test-Rule $Where 'skill/SKILL.md is missing' (Test-Path $Skill)
        Test-Rule $Where 'skill/okf/ is missing (command addons carry OKF knowledge)' (Test-Path $Okf)

        if (Test-Path $CmdDir) {
          $CmdFile = Join-Path $CmdDir 'COMMAND.md'
          Test-Rule "$Where/command" 'COMMAND.md is missing' (Test-Path $CmdFile)
          if (Test-Path $CmdFile) {
            $Fm = Get-Frontmatter $CmdFile
            Test-Rule "$Where/command/COMMAND.md" 'has no frontmatter (it needs at least name:)' ($null -ne $Fm)
            if ($Fm) {
              Test-Rule "$Where/command/COMMAND.md" 'frontmatter has no name:' ($Fm -match '(?m)^name:\s*\S')
            }
          }
        }

        if (Test-Path $Okf) {
          $Index = Join-Path $Okf 'index.md'
          Test-Rule "$Where/skill/okf" 'index.md is missing' (Test-Path $Index)

          foreach ($Md in (Get-ChildItem -Path $Okf -Filter '*.md' -Recurse)) {
            $Rel  = $Md.FullName.Substring($BundleDir.FullName.Length + 1).Replace('\', '/')
            $Fm   = Get-Frontmatter $Md.FullName
            $Name = $Md.Name
            $IsIndex     = ($Rel -eq 'skill/okf/index.md')
            $IsFreeform  = ($Name -eq 'log.md') -or ($Rel -eq 'skill/okf/playbooks/index.md')

            if ($IsFreeform) {
              Test-Rule "$Where/$Rel" 'must have NO frontmatter' ($null -eq $Fm)
              continue
            }

            # An index.md is the ONE place the spec restricts rather than
            # requires: "Index files contain no frontmatter, with one exception:
            # a bundle-root index.md MAY carry an okf_version key" (SPEC.md 8,
            # 12). So no type:, no title:, nothing else - and okf_version is
            # optional, not mandatory.
            if ($IsIndex) {
              if ($null -eq $Fm) { continue }
              foreach ($Line in ($Fm -split "`n")) {
                if ($Line.Trim() -eq '') { continue }
                if ($Line -match '^\s*([A-Za-z_][\w-]*)\s*:') {
                  $Key = $Matches[1]
                  Test-Rule "$Where/$Rel" "index.md frontmatter may only carry okf_version, found '$Key'" ($Key -eq 'okf_version')
                }
              }
              continue
            }

            Test-Rule "$Where/$Rel" 'has no frontmatter' ($null -ne $Fm)
            if ($null -eq $Fm) { continue }

            Test-Rule "$Where/$Rel" 'frontmatter has no type:' ($Fm -match '(?m)^type:\s*\S')
            Test-Rule "$Where/$Rel" 'okf_version belongs to the bundle-root index.md alone' (-not ($Fm -match '(?m)^okf_version:\s*\S'))
          }
        }
      }

      'mcp' {
        $Server = Join-Path $BundleDir.FullName 'mcp/server.json'
        Test-Rule $Where 'mcp/server.json is missing (an mcp addon wires nothing without it)' (Test-Path $Server)
        if (Test-Path $Server) {
          try {
            $Frag = Get-Content -Path $Server -Raw | ConvertFrom-Json
            $Names = @($Frag.PSObject.Properties.Name)
            Test-Rule "$Where/mcp/server.json" 'declares no server' ($Names.Count -gt 0)
            foreach ($N in $Names) {
              Test-Rule "$Where/mcp/server.json" "server '$N' has no command" (-not [string]::IsNullOrWhiteSpace($Frag.$N.command))
            }
          } catch {
            Add-Problem "$Where/mcp/server.json" "does not parse as JSON: $($_.Exception.Message)"
          }
        }
      }
    }

    # --- install targets stay inside ~/.aefos -------------------------------
    if ($Manifest.PSObject.Properties.Name -contains 'install') {
      foreach ($Prop in $Manifest.install.PSObject.Properties) {
        $Target = [string] $Prop.Value
        Test-Rule "$Where/addon.json" "install target '$Target' escapes ~/.aefos (contains '..')" (-not $Target.Contains('..'))
      }
    }

    # --- relative markdown links resolve ------------------------------------
    foreach ($Md in (Get-ChildItem -Path $BundleDir.FullName -Filter '*.md' -Recurse)) {
      $Rel  = $Md.FullName.Substring($BundleDir.FullName.Length + 1).Replace('\', '/')
      $Text = Get-Content -Path $Md.FullName -Raw
      foreach ($M in [regex]::Matches($Text, '\[[^\]]*\]\(([^)]+)\)')) {
        $Link = $M.Groups[1].Value.Trim()
        if ($Link -match '^(https?:|mailto:|#)') { continue }
        $Path = ($Link -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($Path)) { continue }
        $Full = Join-Path (Split-Path -Parent $Md.FullName) $Path
        Test-Rule "$Where/$Rel" "broken relative link: $Link" (Test-Path $Full)
      }
    }
  }
}

# =============================================================================
# 2. registry.json
# =============================================================================
$RegistryPath = Join-Path $RepoRoot 'registry.json'
if (-not (Test-Path $RegistryPath)) {
  Add-Problem 'registry.json' 'is missing'
} else {
  try {
    $Registry = Get-Content -Path $RegistryPath -Raw | ConvertFrom-Json

    $SeenSlugs = @{}
    foreach ($Entry in $Registry.addons) {
      $Slug  = $Entry.slug
      $Where = "registry.json[$Slug]"

      if ($SeenSlugs.ContainsKey($Slug)) {
        Add-Problem $Where 'appears more than once - the registry holds ONE current entry per slug'
      }
      $SeenSlugs[$Slug] = $true

      if (-not $Bundles.ContainsKey($Slug)) {
        Add-Problem $Where 'has no bundle under addons/<type>/ - the registry would point at nothing'
        continue
      }

      $Bundle   = $Bundles[$Slug]
      $Manifest = $Bundle.Manifest

      Test-Rule $Where "version '$($Entry.version)' but the bundle says '$($Manifest.version)'" ($Entry.version -eq $Manifest.version)
      Test-Rule $Where "type '$($Entry.type)' but the bundle lives under addons/$($Bundle.Type)/" ($Entry.type -eq $Bundle.Type)
      Test-Rule $Where 'name drifted from addon.json' ($Entry.name -eq $Manifest.name)
      Test-Rule $Where 'description drifted from addon.json' ($Entry.description -eq $Manifest.description)
      Test-Rule $Where 'sha256 is not a 64-char hex digest' ($Entry.sha256 -match '^[0-9a-f]{64}$')

      # Two tag conventions are in use and both are legitimate: a per-addon tag
      # (<slug>-<version>) for an addon that releases on its own cadence, and a
      # catalogue-wide tag (v<version>) for the batch of specialists published
      # together. What is NOT negotiable is the asset name - the CLI saves and
      # identifies the download by it - and that the version in the URL is the
      # version being published.
      $Asset    = "$Slug-$($Entry.version).zip"
      $ByAddon  = "https://github.com/$Owner/releases/download/$Slug-$($Entry.version)/$Asset"
      $ByBatch  = "https://github.com/$Owner/releases/download/v$($Entry.version)/$Asset"
      $UrlOk    = ($Entry.url -eq $ByAddon) -or ($Entry.url -eq $ByBatch)
      Test-Rule $Where "url is neither release convention`n      per-addon: $ByAddon`n      batch:     $ByBatch`n      found:     $($Entry.url)" $UrlOk
    }

    foreach ($Slug in $Bundles.Keys) {
      if (-not $SeenSlugs.ContainsKey($Slug)) {
        Add-Problem "addons/$($Bundles[$Slug].Type)/$Slug" 'has a bundle but no registry.json entry - nobody can install it'
      }
    }
  } catch {
    Add-Problem 'registry.json' "does not parse as JSON: $($_.Exception.Message)"
  }
}

# =============================================================================
# Report
# =============================================================================
Write-Host ''
Write-Host "Catalogue: $($Bundles.Count) addons, $($script:Checked) checks."
Write-Host ''

if ($script:Problems.Count -eq 0) {
  Write-Host 'PASS - the catalogue is consistent.' -ForegroundColor Green
  exit 0
}

Write-Host "FAIL - $($script:Problems.Count) problem(s):" -ForegroundColor Red
foreach ($P in $script:Problems) {
  Write-Host "  - $P" -ForegroundColor Red
}
Write-Host ''
exit 1
