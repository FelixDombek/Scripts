<#
.SYNOPSIS
    Compares the file systems of two directories and outputs the differences.
.DESCRIPTION
    This script takes two directory paths as input, compares their file systems,
    and outputs the differences. It identifies files that exist in only one directory
    or have different sizes and outputs the results with appropriate symbols ("- ", "+ ", "? ").

.PARAMETER folderPath1
    Specifies the path of the first directory to compare.

.PARAMETER folderPath2
    Specifies the path of the second directory to compare.

.EXAMPLE
    .\Compare-Directories.ps1 -folderPath1 "C:\Path\To\Directory1" -folderPath2 "C:\Path\To\Directory2"
    Compares the file systems of two directories and outputs the differences.
#>

param (
    [Parameter(Mandatory=$true)][string]$folderPath1,
    [Parameter(Mandatory=$true)][string]$folderPath2
)

$scriptPath = ".\Get-ChildItemsProgress.ps1"
. $scriptPath

# Function to normalize paths
function Canonicalize-Path($path) {
    return (Get-Item -LiteralPath $path).FullName
}

# Function to get relative path
function Get-RelativePath($basePath, $fullPath) {
    $basePath = Canonicalize-Path $basePath
    $fullPath = Canonicalize-Path $fullPath

    return $fullPath.Substring($basePath.Length + [int]!$basePath.EndsWith("\"))
}

function List-Directories($folderPath1, $folderPath2) {
    $scriptBlock = {
        param ($folderPath)

        # Use the imported function
        $files = Get-ChildItemsRec -FolderPath $folderPath -noProgress $true
        return $files
    }

    $initScriptBlock = [scriptblock]::Create((Get-Content $scriptPath -Raw))

    $job1 = Start-ThreadJob -ScriptBlock $scriptBlock -ArgumentList $folderPath1 -InitializationScript $initScriptBlock
    $job2 = Start-ThreadJob -ScriptBlock $scriptBlock -ArgumentList $folderPath2 -InitializationScript $initScriptBlock

    Write-Progress -Activity "Listing files" -Status $folderPath1 -PercentComplete 5

    $null = Wait-Job -Any $job1, $job2
    
    Write-Progress -Activity "Listing files" -Status $folderPath2 -PercentComplete 35

    $null = Wait-Job $job1, $job2

    $files1 = Receive-Job -Job $job1 -Wait
    $files2 = Receive-Job -Job $job2 -Wait

    Remove-Job -Job $job1
    Remove-Job -Job $job2

    return $files1, $files2
}

# Get file lists for both directories in parallel
$files1, $files2 = List-Directories $folderPath1 $folderPath2
Write-Progress -Activity "Listing files done" -Status $folderPath2 -PercentComplete 100

#$files1 = Get-ChildItemsRec -FolderPath $folderPath1
#$files2 = Get-ChildItemsRec -FolderPath $folderPath2

# Initialize indices
$index1 = 0
$index2 = 0
$count1 = $files1.Count
$count2 = $files2.Count
$countTotal = $count1 + $count2

while ($index1 -lt $files1.Count -and $index2 -lt $files2.Count) {    
    $file1 = $files1[$index1]
    $file2 = $files2[$index2]    

    $relativePath1 = Get-RelativePath $folderPath1 $file1.FullName
    $relativePath2 = Get-RelativePath $folderPath2 $file2.FullName

    if ($relativePath1 -eq $relativePath2) {
        # Files have the same relative path
        if ($file1.Length -ne $file2.Length) {
            Write-Output ("? $relativePath1")
        }

        Write-Progress -Activity "Compare" -Status ("$($index1 + $index2)/$countTotal  $relativePath1") -PercentComplete (($index1 + $index2)*100.0/$countTotal)

        # Increment both indices
        $index1++
        $index2++
    } elseif ($relativePath1 -lt $relativePath2) {
        # File only in the first directory
        Write-Progress -Activity "Compare" -Status ("$($index1 + $index2)/$countTotal  $relativePath1") -PercentComplete (($index1 + $index2)*100.0/$countTotal)
        Write-Output ("- $relativePath1")
        $index1++
    } else {
        # File only in the second directory
        Write-Progress -Activity "Compare" -Status ("$($index1 + $index2)/$countTotal  $relativePath2") -PercentComplete (($index1 + $index2)*100.0/$countTotal)
        Write-Output ("+ $relativePath2")
        $index2++
    }
}

# Output remaining files from the first directory
while ($index1 -lt $files1.Count) {
    $file1 = $files1[$index1]
    $relativePath1 = Get-RelativePath $folderPath1 $file1.FullName

    Write-Progress -Activity "Compare" -Status ("$($index1 + $index2)/$countTotal  $relativePath1") -PercentComplete (($index1 + $index2)*100.0/$countTotal)

    Write-Output ("- $relativePath1")
    $index1++
}

# Output remaining files from the second directory
while ($index2 -lt $files2.Count) {
    $file2 = $files2[$index2]
    $relativePath2 = Get-RelativePath $folderPath2 $file2.FullName

    Write-Progress -Activity "Compare" -Status ("$($index1 + $index2)/$countTotal  $relativePath2") -PercentComplete (($index1 + $index2)*100.0/$countTotal)

    Write-Output ("+ $relativePath2")
    $index2++
}
