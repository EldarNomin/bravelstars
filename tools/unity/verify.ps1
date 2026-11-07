param(
    [string]$UnityEditor = 'C:\Program Files\Unity\Hub\Editor\6000.3.25f1\Editor\Unity.exe',
    [switch]$WithAndroid
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$projectRoot = Join-Path $repoRoot 'unity'
$evidenceRoot = Join-Path $repoRoot 'artifacts/unity'
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
Push-Location $repoRoot
try {
    python tools/unity/export_data.py --check
    if ($LASTEXITCODE -ne 0) { throw 'Migration data is stale' }
    python tools/unity/verify_models.py
    if ($LASTEXITCODE -ne 0) { throw 'Model conversion differs from source' }
    dotnet run --project tools/unity/checks/Checks.csproj --configuration Release
    if ($LASTEXITCODE -ne 0) { throw 'Simulation checks failed' }
    if (-not (Test-Path -LiteralPath $UnityEditor)) { throw "Unity Editor missing: $UnityEditor" }
    $buildLog = Join-Path $evidenceRoot 'windows-build.log'
    $editorArgs = @('-batchmode', '-quit', '-projectPath', ('"' + $projectRoot + '"'), '-executeMethod', 'Bravel.Editor.MobileBuild.Windows', '-logFile', ('"' + $buildLog + '"'))
    $editorProcess = Start-Process -FilePath $UnityEditor -ArgumentList $editorArgs -WindowStyle Hidden -PassThru -Wait
    if ($editorProcess.ExitCode -ne 0) { throw "Unity build failed; see $buildLog" }
    $player = Join-Path $projectRoot 'Builds/Windows/Bravel.exe'
    foreach ($resolution in @(@(1280, 720), @(1600, 720), @(960, 720))) {
        $folder = Join-Path $evidenceRoot ($resolution[0].ToString() + 'x' + $resolution[1])
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        foreach ($marker in @('runtime.txt', 'runtime-failed.txt')) {
            $markerPath = Join-Path $folder $marker
            if (Test-Path -LiteralPath $markerPath) { Remove-Item -LiteralPath $markerPath }
        }
        $playerLog = Join-Path $folder 'player.log'
        $playerArgs = @('-batchmode', '-force-d3d11', '-screen-fullscreen', '0', '-screen-width', $resolution[0], '-screen-height', $resolution[1], '-bravelSmoke', '-bravelEvidence', ('"' + $folder + '"'), '-logFile', ('"' + $playerLog + '"'))
        $playerProcess = Start-Process -FilePath $player -ArgumentList $playerArgs -WindowStyle Hidden -PassThru
        if (-not $playerProcess.WaitForExit(120000)) { Stop-Process -Id $playerProcess.Id; throw "Runtime smoke timeout; see $playerLog" }
        $playerProcess.Refresh()
        if ($playerProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $folder 'runtime.txt'))) { throw "Runtime smoke failed; see $playerLog" }
    }
    if ($WithAndroid) {
        $androidLog = Join-Path $evidenceRoot 'android-build.log'
        $androidArgs = @('-batchmode', '-quit', '-buildTarget', 'Android', '-projectPath', ('"' + $projectRoot + '"'), '-executeMethod', 'Bravel.Editor.MobileBuild.Android', '-logFile', ('"' + $androidLog + '"'))
        $androidProcess = Start-Process -FilePath $UnityEditor -ArgumentList $androidArgs -WindowStyle Hidden -PassThru -Wait
        if ($androidProcess.ExitCode -ne 0) { throw "Android build failed; see $androidLog" }
        python tools/unity/verify_apk.py (Join-Path $projectRoot 'Builds/Android/bravelstars-unity-debug.apk') --output (Join-Path $evidenceRoot 'apk.json')
        if ($LASTEXITCODE -ne 0) { throw 'APK native-library checks failed' }
    }
    Write-Output "Verification passed. Evidence: $evidenceRoot"
} finally { Pop-Location }
