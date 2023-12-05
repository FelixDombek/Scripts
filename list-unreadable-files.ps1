<#
.SYNOPSIS
    This script recursively reads files in a specified folder and its subdirectories, finding read errors.
.DESCRIPTION
    Read errors are written to the console and optionally a file.
.PARAMETER folderPath
    Specifies the folder path to start the recursive operation.
.PARAMETER outputFileName
    Specifies the optional output file.
.EXAMPLE
    .\list-unreadable-files.ps1 -folderPath "C:\Path\To\Your\Folder"
    Runs the script on the specified folder and its subdirectories.
#>

param (
    [Parameter(Mandatory=$true)][string]$folderPath,
    [string]$outputFileName
)

Import-Module Write-ProgressEx

if (-not $folderPath) {
    Write-Error "Please provide a folder path using the -folderPath parameter."
    exit
}

$global:items = Get-ChildItem -Path $folderPath -Recurse -Force -Attributes !Directory | Write-ProgressEx $folderPath
$global:totalItems = $global:items.Count
$global:readItems = 0
$global:totalBytes = ($global:items | Measure-Object -Property Length -Sum).Sum
$global:readBytes = 0
$global:totalGB = $global:totalBytes / (1000*1000*1000)
$global:startTime = Get-Date
$global:numErrors = 0
$global:chunkSize = 10MB
$global:buffer = [byte[]]::new($global:chunkSize)

function Update-ProgressWithThroughput($filePath) {
    $elapsedTime = (Get-Date) - $global:startTime
    $throughputBps = $global:readBytes / $elapsedTime.TotalSeconds
    $remainingSeconds = [math]::Min(($global:totalBytes - $global:readBytes) / [math]::Max($throughputBps, 1), [Int32]::MaxValue)
    $throughputMBps = $throughputBps / (1000*1000)
    $remainingTime = New-TimeSpan -Seconds $remainingSeconds
    $status = "{0}!{1}/{2}  {3:N2}/{4:N2}GB  {5:N2}MB/s  {6}  {7}" -f `
        $global:numErrors, ` # 0
        $global:readItems, ` # 1
        $global:totalItems, ` #2
        ($global:readBytes / (1000*1000*1000)), ` # 3
        $global:totalGB, ` # 4
        $throughputMBps, ` # 5
        $remainingTime.ToString("hh\:mm\:ss"), ` # 6
        $filePath # 7
    Write-Progress -Activity "█" -Status $status -PercentComplete ($readBytes * 100.0 / $totalBytes)
}

function ReadFile($filePath) {
    try {
        ++$global:readItems
        $fileStream = [System.IO.File]::OpenRead($filePath)
        while ($true) {
            Update-ProgressWithThroughput -filePath $filePath
            $bytesRead = $fileStream.Read($global:buffer, 0, $global:chunkSize)
            $global:readBytes += $bytesRead
            if ($bytesRead -lt $chunkSize) { break }
        }
    }
    catch {
        ++$global:numErrors
        $errorMessage = "{0} : 0x{1:x} : {2}" -f $filePath, $_.Exception.HResult, $_.Exception.Message
        Write-Output $errorMessage
        if ($outputFileName) {
            Add-Content -Path $outputFileName -Value $errorMessage
        }
    }
    finally {
        if ($fileStream) { $fileStream.Close() }
    }
}

if ($outputFileName) {
    Clear-Content -Path $outputFileName
}

foreach ($item in $global:items) {
    ReadFile -FilePath $item.FullName
}
