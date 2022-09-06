function Update-Sysinternals {
  [Cmdletbinding()]
  param (
    [string]
    $Uri = 'https://download.sysinternals.com/files/SysinternalsSuite.zip',
    [string]
    $OutFile = "$($env:HomeDrive)$($env:HOMEPATH)\Downloads\SysinternalsSuite.zip",
    [string]
    $Destination = "$env:HomeDrive\SysInternals",
    [switch]
    $RemoveDownloadFile,
    [switch]
    $UpdateCurrentPathEnvironmentVariable,
    [switch]
    $UpdateStoredPathEnvironmentVariable
  )

  try {
    # Download the new zip file of tools
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Verbose -ErrorAction Stop

    # Get the list of files before the update
    if (!(Test-Path -Path $Destination)) {
      $null = New-Item -Path $Destination -ItemType Directory -Force
    }
    $Files = Get-ChildItem -Path $Destination
    $Files = $Files | Select-Object *, @{Name="LastWriteDate";Expression={Get-Date(Get-Date $_.LastWriteTime -Format 'yyyy-MM-dd')}}

    # Kill any running sysinternals apps processes that may be locked
    $Running = Get-Process zoomit*, desktops*, procexp* -ErrorAction SilentlyContinue
    $Paths = $Running | Where-Object { $_.name -notlike '*64' } | Select-Object -Property Path
    if ($Running) {
      $Running | Stop-Process -Force -Verbose
    }
    Add-Type -AN System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($OutFile)
    $extractedCount = 0
    $zipFileData = $zip.Entries
    $zipFileData = $zipFileData | Select-Object *, @{Name="LastWriteDate";Expression={Get-Date(Get-Date $_.LastWriteTime.DateTime -Format 'yyyy-MM-dd')}}
    if ($null -eq $Files) {
      $missingOrUpdatedFiles = $zip.Entries
    } else {
      $fileDiff = Compare-Object -ReferenceObject $Files -DifferenceObject $zipFileData -Property Name, LastWriteDate | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty Name
      $missingOrUpdatedFiles = $zip.Entries | Where-Object { $_.Name -in $fileDiff }
    }
    $missingOrUpdatedFiles |
    ForEach-Object {
      # Extract the selected item(s)
      Write-Verbose -Message ('Extracting missing or updated file: {0}' -f $_.Name) -Verbose
      $ExtractFileName = $_.Name
      $ExtractFileNamePath = ("$Destination\$ExtractFileName")
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $ExtractFileNamePath, $true)
      $extractedCount++
    }
    Write-Verbose -Message ('Extracted {0} files.' -f $extractedCount) -Verbose

    #Check that destination of files is in the environment Path variable
    if ($UpdateCurrentPathEnvironmentVariable) {
      Update-PathEnvironmentVariable -NewPath $Destination
    }
    if ($UpdateStoredPathEnvironmentVariable) {
      Update-PathEnvironmentVariable -NewPath $Destination -UpdateRegistry
    }
    if ($RemoveDownloadFile) {
      $zip.Dispose()
      Start-Sleep -Seconds 2
      Remove-Item -Path $OutFile -Force
    }
    # Restart any applications that were running previously
    if ($Paths) {
      $Paths | ForEach-Object { Start-Process -FilePath $_.Path }
    }
  } Catch {
    Write-Warning -Message $_
  } finally {
    $zip.Dispose()
  }
}#End function Update-Sysinternals
