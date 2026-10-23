param(
    [ValidateSet('windows','web')][string]$Platform='windows',
    [ValidateSet('template_debug','template_release')][string]$Target='template_debug',
    [string]$Python='python',[string]$MsvcTools='',[string]$WindowsSdk='',[string]$Emsdk='',[int]$Jobs=8
)
$ErrorActionPreference='Stop'
$env:PYTHONUTF8='1'
$project=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path "$project/native/godot-cpp/SConstruct")) { throw 'Install the pinned godot-cpp SDK described in native/README.md.' }
if (Test-Path "$project/.godot/build_tools") { $env:PYTHONPATH="$project/.godot/build_tools"+[IO.Path]::PathSeparator+$env:PYTHONPATH }
if ($Platform -eq 'windows') {
    if ($MsvcTools) {
        if (-not $WindowsSdk) { throw '-WindowsSdk is required with -MsvcTools.' }
        $sdkVersion=(Get-ChildItem "$WindowsSdk/Include" -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
        $env:PATH="$MsvcTools/bin/HostX64/x64;"+$env:PATH
        $env:INCLUDE="$MsvcTools/include;$WindowsSdk/Include/$sdkVersion/ucrt;$WindowsSdk/Include/$sdkVersion/shared;$WindowsSdk/Include/$sdkVersion/um"
        $env:LIB="$MsvcTools/lib/x64;$WindowsSdk/Lib/$sdkVersion/ucrt/x64;$WindowsSdk/Lib/$sdkVersion/um/x64"
    }
    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw 'Use x64 Developer PowerShell or provide compiler roots.' }
    $architecture='x86_64';$threadOption='threads=yes'
} else {
    if (-not $Emsdk) { $Emsdk="$project/.godot/emsdk" }
    $env:PATH="$Emsdk/upstream/emscripten;"+$env:PATH
    $env:EMSDK_PYTHON=(Get-Command $Python).Source
    if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) { throw 'Install Emscripten 4.0.20.' }
    $architecture='wasm32';$threadOption='threads=no'
}
Push-Location "$project/native"
try {
    & $Python -m SCons "platform=$Platform" "target=$Target" "arch=$architecture" $threadOption build_profile=build_profile.json "-j$Jobs"
    if ($LASTEXITCODE -ne 0) { throw 'Road graph build failed.' }
} finally { Pop-Location }

