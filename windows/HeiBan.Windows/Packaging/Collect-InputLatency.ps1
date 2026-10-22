[CmdletBinding()]
param([Parameter(Mandatory)][string]$Executable,[string]$Output)
$ErrorActionPreference='Stop'
$exe=(Resolve-Path -LiteralPath $Executable).Path
if([IO.Path]::GetFileName($exe) -ne 'HeiBan.exe'){throw '請選取 HeiBan.exe。'}
if(@(Get-CimInstance Win32_Process -Filter "Name = 'HeiBan.exe'"|Where-Object {$_.ExecutablePath -eq $exe}).Count){throw '請先正常儲存並關閉這份試用版，再開始採樣。'}
if(-not $Output){$Output=Join-Path ([IO.Path]::GetDirectoryName($exe)) ('input-latency-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.json')}
$report=[IO.Path]::GetFullPath($Output)
if(Test-Path -LiteralPath $report){throw '採樣檔已存在；請另選新檔名。'}
$previous=[Environment]::GetEnvironmentVariable('HEIBAN_INPUT_TRACE','Process')
try{
    $env:HEIBAN_INPUT_TRACE=$report
    Write-Host '請照常畫線、連續起筆、切換工具；完成後正常關閉 HeiBan，才會寫出本機數值報告。'
    Write-Host ('報告位置：'+$report)
    # This user-invoked capture is interactive: the app must be visible so the
    # user can reproduce the stutter. No unattended input is generated here.
    $app=Start-Process -FilePath $exe -WorkingDirectory ([IO.Path]::GetDirectoryName($exe)) -WindowStyle Normal -PassThru
    $app.WaitForExit()
    if(Test-Path -LiteralPath $report){Write-Host '採樣已儲存。'}else{Write-Warning '本次未產生報告；請確認使用支援採樣的新試用版並正常關閉。'}
}finally{[Environment]::SetEnvironmentVariable('HEIBAN_INPUT_TRACE',$previous,'Process')}
