<#
 Build a signed release APK and upload it to Firebase App Distribution.

   .\tool\distribute.ps1 -DryRun                 # build only, upload nothing
   .\tool\distribute.ps1 -Notes "Login biometrik"  # build + upload to group "asatidz"

 Needs: flutter, firebase CLI logged in to an account with access to the project
 (`firebase login`), and android/key.properties + keystore (see docs in README).
 versionCode = number of git commits, so every build installs over the previous one.
#>
param(
    [string]$Groups = 'asatidz',
    [string]$Notes = '',
    [string]$ApiBaseUrl = 'https://staging.persis50lembang.sch.id/api',
    [string]$FirebaseApp = '1:144021785442:android:5354c50772111c17337a3b',
    [string]$Project = 'asatidz-persis-50',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path android/key.properties)) {
    throw 'android/key.properties not found: the release would be signed with the debug key.'
}
if (git status --porcelain --untracked-files=no) {
    Write-Warning 'Working tree has uncommitted changes; the build will include them.'
}

$build = (git rev-list --count HEAD).Trim()
if (-not $Notes) { $Notes = (git log -1 --pretty=%s).Trim() }

flutter build apk --release --build-number=$build "--dart-define=API_BASE_URL=$ApiBaseUrl"
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
$apk = 'build/app/outputs/flutter-apk/app-release.apk'
Write-Host "Built $apk (build $build, API $ApiBaseUrl)"

if ($DryRun) { Write-Host 'DryRun: nothing uploaded.'; return }

firebase appdistribution:distribute $apk --app $FirebaseApp --project $Project `
    --groups $Groups --release-notes $Notes
if ($LASTEXITCODE -ne 0) { throw 'firebase upload failed' }
