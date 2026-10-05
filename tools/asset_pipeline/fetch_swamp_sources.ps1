$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$sourceRoot = Join-Path $projectRoot 'work\animal_sources'
$receipt = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'reports\swamp_sources_receipt.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $sourceRoot '.gdignore') -Value ''

function Receive-VerifiedSource {
    param([string]$Uri, [string]$Destination, [string]$ExpectedSha256)
    if (-not (Test-Path -LiteralPath $Destination)) {
        Invoke-WebRequest -Uri $Uri -OutFile $Destination
    }
    $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "Source hash differs for $Destination. Inspect the upstream asset before updating its receipt."
    }
}

Receive-VerifiedSource $receipt.frog.download (Join-Path $sourceRoot 'frog.tar.gz') $receipt.frog.package_sha256
Receive-VerifiedSource $receipt.snake.download (Join-Path $sourceRoot 'snake.tar.gz') $receipt.snake.package_sha256
Receive-VerifiedSource $receipt.turtle.download (Join-Path $sourceRoot 'Turtle.blend') $receipt.turtle.package_sha256
Receive-VerifiedSource $receipt.turtle.texture_download (Join-Path $sourceRoot 'turtle_texture.png') '9188a478d1ab63c4280723426d8fee1b6276e6eaed868e39d4fa9a19ef097076'

foreach ($species in @('frog', 'snake')) {
    $archive = Join-Path $sourceRoot ($species + '.tar.gz')
    $destination = Join-Path $sourceRoot $species
    $members = & tar -tzf $archive
    if ($LASTEXITCODE -ne 0) { throw "Unable to list source archive $archive" }
    foreach ($member in $members) {
        if ($member -match '(^[/\\]|^[A-Za-z]:|(^|[/\\])\.\.([/\\]|$))') {
            throw "Archive path leaves its extraction directory: $member"
        }
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    & tar -xzf $archive -C $destination
    if ($LASTEXITCODE -ne 0) { throw "Unable to extract source archive $archive" }
    $blend = Join-Path $destination ($species + '\' + $species + '.blend')
    $actualHash = (Get-FileHash -LiteralPath $blend -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $receipt.$species.blend_sha256) { throw "Extracted source hash differs for $blend" }
}
Write-Output 'SWAMP_SOURCES_VERIFIED: frog, snake, turtle (CC0)'
