function Update-Sysinternals {
  param (
    $Uri = 'https://download.sysinternals.com/files/SysinternalsSuite.zip',
    $OutFile = "$($env:HomeDrive)$($env:HOMEPATH)\Downloads\SysinternalsSuite.zip",
    $Destination = "$env:HomeDrive\SysInternals"
  )

  try {
  # Download the new zip file of tools
  Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Verbose
  } catch {
    "Cannot connect to: $Uri, please ensure you are connected to the Internet."
  }
  try {
    # Get the list of files before the update
    if (!(Test-Path -Path $Destination)) {
      $null = New-Item -Path $Destination -ItemType Directory -Force
    }
    $Files = Get-ChildItem -Path $Destination
    # Kill any running sysinternals apps processes that may be locked
    $Running = Get-Process zoomit*, desktops*, procexp* -ErrorAction SilentlyContinue
    $Paths = $Running | Where-Object { $_.name -notlike '*64' } | Select-Object -Property Path
    if ($Running) {
      $Running | Stop-Process -Force -Verbose
    }
    Expand-Archive -LiteralPath $OutFile -DestinationPath $Destination -Force
    $FilesUpdate = Get-ChildItem -Path $Destination
    #Check that destination of files is in the environment Path variable
    Update-PathEnvironmentVariable -NewPath $Destination -UpdateRegistry
    if ($null -eq $Files) {
      $Updates = $FilesUpdate |
        ForEach-Object { $_ } | Select-Object Name, CreationTime
    } else {
      $Updates = Compare-Object -ReferenceObject $Files -DifferenceObject $FilesUpdate |
        Select-Object -ExpandProperty InputObject |
        ForEach-Object { Get-ChildItem -Path $Destination\$_ } | Select-Object Name, CreationTime
    }
    if ($Updates) {
      Write-Host 'Updated the following commands:'
      $Updates
    }
  } Catch {
    Write-Warning -Message $_
  } finally {
    # Restart any applications that were running previously
    if ($Paths) {
      $Paths | ForEach-Object { Start-Process -FilePath $_.Path }
    }
  }
}#End function Update-Sysinternals
