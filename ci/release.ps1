param(
    [Parameter(Mandatory)]
    [ValidateSet('Prepare', 'Activate', 'Verify', 'Recover', 'Rollback')]
    [string]$Action,

    [string]$Release
)

$ErrorActionPreference = 'Stop'

if (-not $env:PRACTICE_RELEASE_ROOT) {
    if (-not $env:JENKINS_HOME) { throw 'Set PRACTICE_RELEASE_ROOT or run from Jenkins.' }
    $env:PRACTICE_RELEASE_ROOT = Join-Path (Split-Path $env:JENKINS_HOME) 'deployment'
}

$root = $env:PRACTICE_RELEASE_ROOT
$pointer = Join-Path $root 'current.txt'
$previous = Join-Path $root 'previous.txt'
$pending = Join-Path $root 'pending.txt'
$prior = Join-Path $root 'prior.txt'

function Read-Pointer($Path) {
    if (Test-Path -LiteralPath $Path) {
        [IO.File]::ReadAllText($Path).Trim()
    }
}

function Write-Pointer($Path, [string]$Value) {
    $temporary = "$Path.new"
    [IO.File]::WriteAllText($temporary, $Value)
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.bak"
        [IO.File]::Replace($temporary, $Path, $backup)
        Remove-Item -LiteralPath $backup
    } else {
        [IO.File]::Move($temporary, $Path)
    }
}

function Test-Health($Expected) {
    $response = Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8001/up' -TimeoutSec 15
    if ($response.StatusCode -ne 200 -or $response.Headers['X-Practice-Release'] -ne $Expected) {
        throw "Health check did not reach release $Expected."
    }
    Write-Output "HTTP 200 from release $Expected"
}

function Recover-Release {
    $pendingRelease = Read-Pointer $pending
    if ($pendingRelease -and $pendingRelease -eq $Release) {
        if ((Read-Pointer $pointer) -eq $Release) {
            Write-Pointer $pointer (Read-Pointer $prior)
        }
        Remove-Item -LiteralPath $pending
    }
}

if ($Action -eq 'Recover' -and -not (Test-Path -LiteralPath $pending)) { exit 0 }

if (-not $Release -and $Action -ne 'Rollback') {
    if (-not $env:BUILD_NUMBER) { throw 'Set a Jenkins build number or pass -Release.' }
    $revision = git rev-parse --short=12 HEAD
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    $Release = "$env:BUILD_NUMBER-$revision"
}

if ($Action -ne 'Rollback' -and $Release -notmatch '^[0-9]+-[a-f0-9]{12}$') {
    throw 'Release must be a build number followed by a 12-character Git revision.'
}

$releases = Join-Path $root 'releases'

switch ($Action) {
    'Prepare' {
        $destination = Join-Path $releases $Release
        $archive = Join-Path $releases "$Release.zip"
        if (Test-Path -LiteralPath $destination) { throw 'Release directory already exists.' }
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        git archive --format=zip -o $archive HEAD
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        Expand-Archive -LiteralPath $archive -DestinationPath $destination
        Remove-Item -LiteralPath $archive
        @'
APP_NAME="Laravel CI/CD Practice"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://127.0.0.1:8001
SESSION_DRIVER=array
CACHE_STORE=array
QUEUE_CONNECTION=sync
'@ | Set-Content -LiteralPath (Join-Path $destination '.env') -Encoding ascii
        Push-Location -LiteralPath $destination
        try {
            composer install --no-dev --no-interaction --prefer-dist --no-progress
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
            php artisan key:generate --force --no-interaction
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
        } finally {
            Pop-Location
        }
    }
    'Activate' {
        if (Test-Path -LiteralPath $pending) { throw 'A deployment is already pending verification.' }
        if (-not (Test-Path -LiteralPath (Join-Path $releases "$Release/vendor/autoload.php"))) {
            throw 'Release dependencies are missing.'
        }
        Write-Pointer $prior (Read-Pointer $pointer)
        Write-Pointer $pending $Release
        Write-Pointer $pointer $Release
    }
    'Verify' {
        if ((Read-Pointer $pending) -ne $Release) { throw 'No matching deployment is pending.' }
        try {
            Test-Health $Release
            Write-Pointer $previous (Read-Pointer $prior)
            Remove-Item -LiteralPath $pending
        } catch {
            Recover-Release
            throw
        }
    }
    'Recover' {
        Recover-Release
    }
    'Rollback' {
        if (Test-Path -LiteralPath $pending) { throw 'Finish the current deployment before rolling back.' }
        $current = Read-Pointer $pointer
        $target = Read-Pointer $previous
        if ($target -notmatch '^[0-9]+-[a-f0-9]{12}$') { throw 'No previous release to restore.' }
        Write-Pointer $pointer $target
        try {
            Test-Health $target
            Write-Pointer $previous $current
        } catch {
            Write-Pointer $pointer $current
            throw
        }
    }
}
