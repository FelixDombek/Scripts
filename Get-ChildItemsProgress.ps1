<#
.SYNOPSIS
    Recursively retrieves non-directory items within a specified folder and its subdirectories.

.DESCRIPTION
    This script recursively explores the specified folder and its subdirectories,
    outputting non-directory items and calculating progress based on the total number of subdirectories.

.PARAMETER FolderPath
    Specifies the folder path to start the recursive operation.

.EXAMPLE
    Get-ChildItemsProgress -FolderPath "C:\Path\To\Your\Folder"

    Runs the script on the specified folder and its subdirectories.

#>

function Get-ChildItemsRec {
    param (
        [Parameter(Mandatory = $true)][string]$FolderPath,
        [bool]$noProgress = $false
    )

    function Get-ItemsRecursively {
        param (
            [Parameter(Mandatory = $true)][string]$Path,
            [Parameter(Mandatory = $true)][double]$SubProgressStart,
            [Parameter(Mandatory = $true)][double]$SubProgressEnd
        )

        $items = Get-ChildItem -Path $Path -Force
        $subdirectoryCount = ($items | Where-Object { $_.PSIsContainer }).Count

        $subdirectorySlice = ($SubProgressEnd - $SubProgressStart) / $subdirectoryCount
        $subProgress = $SubProgressStart

        foreach ($item in $items) {
            if (-not $item.PSIsContainer) {
                Write-Output $item
            }

            if ($item.PSIsContainer) {
                if (-not $noProgress) {
                    $status = "$item............................................................................................................"
                    Write-Progress -Activity ("{0:N2}%" -f $subProgress) -Status $status -PercentComplete $subProgress
                }

                Get-ItemsRecursively -Path $item.FullName -SubProgressStart $subProgress -SubProgressEnd ($subProgress + $subdirectorySlice)
                $subProgress += $subdirectorySlice
            }
        }
    }

    Get-ItemsRecursively -Path $FolderPath -SubProgressStart 0 -SubProgressEnd 100
}