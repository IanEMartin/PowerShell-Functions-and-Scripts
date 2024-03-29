function Update-PathEnvironmentVariable {
  param (
  [Parameter(Mandatory)]
  [ValidateScript( {
      if ($_ -match '^[C-Zc-z]{1}:\\[\w+|\w+\\]*') {
        $true
      } else {
        Throw 'Path provided must be standard windows path format (example: d:\Dir1\Dir2\Dir3)'
      }
    })]
    [string]
    $NewPath,
    [switch]
    $UpdateRegistry,
    [switch]
    $Clean
  )

  $newPathExists = $false
  $result = $null
  try {
    $NewPath = $NewPath.Trim()
    $result = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH
    # $result = REG QUERY 'HKLM\System\CurrentControlSet\Control\Session Manager\Environment' /V PATH
    if ([string]::IsNullOrEmpty($result)) {
      throw 'Unable to retrieve current path variable from registry.'
    }
    $PathRegistryEnvString = $result
    # $PathRegistryEnvString = $null
    # $result |
    #   ForEach-Object {
    #     if(!([string]::IsNullOrEmpty($_) -or $_ -match 'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment')) {
    #       $PathRegistryEnvString += $_
    #     }
    #   }
    # $PathRegistryEnvString = $PathRegistryEnvString -replace '^\s*PATH\s*REG_EXPAND_SZ\s*', ''
    $PathRegistryEnvString = $PathRegistryEnvString -replace ';;', ';'
    $PathRegistryEnvStringSplit = $null
    if ($Clean) {
      $PathRegistryEnvStringSplit = ($PathRegistryEnvString | Select-Object -Unique) -split ';' | Sort-Object
    } else {
      $PathRegistryEnvStringSplit = ($PathRegistryEnvString | Select-Object -Unique) -split ';'
    }
    $NewRegistryEnvString = $null
    $PathRegistryEnvStringSplit | ForEach-Object {
      if ($_ -match '%[A-Za-z]*%') {
        $pathToTest = $_
        do {
          $replaceString = $Matches[0]
          $envVariableName = $replaceString -replace '%', ''
          $newString = [Environment]::GetEnvironmentVariable($envVariableName)
          $pathToTest = $pathToTest -replace $replaceString, $newString
        } until (($pathToTest -match '%[A-Za-z]*%') -eq $false)
      } else {
        $pathToTest = $_
      }
      if ($pathToTest -eq $NewPath) {
        $newPathExists = $true
      }
      if ($Clean) {
        if (Test-Path -Path $pathToTest) {
          $NewRegistryEnvString += "$_;"
        } else {
          Write-Verbose -Message ('Path [{0}] does not exist.  Removing from path.' -f $_) -Verbose
        }
      } else {
        $NewRegistryEnvString += "$_;"
      }
    }
    $NewRegistryEnvStringSplit = $NewRegistryEnvString -split ';'
    if ($newPathExists -eq $false) {
      $NewRegistryEnvStringSplit += $NewPath
    }
    $NewRegistryEnvStringSplit = $NewRegistryEnvStringSplit | Where-Object { $_ -ne '' } | Sort-Object
    $NewRegistryEnvString = $NewRegistryEnvStringSplit -join ';'
    # $NewRegistryEnvString
    if ($UpdateRegistry) {
      if ($newPathExists) {
        Write-Verbose -Message ('Path already in stored environment paths.  No changes made.') -Verbose
      } else {
        # Set the registry key
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $NewRegistryEnvString
        Write-Verbose -Message ('{0}[{1}] added to{2}STORED{3} environment paths.' -f "`e[22m", $NewPath, " `e[1m", "`e[22m") -Verbose
        $result = Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH
        $result.Path
      }
    }
    # Update current environment
    $currentEnvironmentPath = $env:PATH
    $currentEnvironmentPath = $currentEnvironmentPath | Where-Object { $_ -ne '' } | Sort-Object
    $currentEnvironmentPathSplit = $currentEnvironmentPath -split ';'
    if ($NewPath -in $currentEnvironmentPathSplit) {
      $newPathExists = $true
    }
    if ($newPathExists) {
      Write-Verbose -Message ('Path already in current environment paths.  No changes made.') -Verbose
    } else {
      $env:PATH = "$env:PATH;$NewPath"
      Write-Verbose -Message ('{0}[{1}] added to{2}CURRENT{3} environment paths.' -f "`e[22m", $NewPath, " `e[1m", "`e[22m") -Verbose
    }
    $env:PATH
  } catch {
    Write-Warning -Message $_
  }
}
