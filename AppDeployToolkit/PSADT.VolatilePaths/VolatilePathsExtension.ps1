<#
.SYNOPSIS
	Volatile Paths Extension script file, must be dot-sourced by the AppDeployToolkitExtension.ps1 script.
.DESCRIPTION
	Use system methods to enqueue a movement (rename) or delete files or folder after reboot.
	Creates registry keys that are automatically deleted after reboot.
.NOTES
	Extension Exit Codes:
	70201: New-PendingFileRenameOperation - Administrative rights are needed to register movement (rename) after reboot.
	70202: New-PendingFileRenameOperation - Administrative rights are needed to register delete after reboot.
	70203: Move-FileAfterReboot - Failed to register movement (rename) of file after reboot.
	70204: Move-FolderAfterReboot - Failed to register movement (rename) of folder after reboot.
	70205: Remove-FileAfterReboot - Failed to register delete of file after reboot.
	70206: Remove-FolderAfterReboot - Failed to register delete of folder after reboot.
	70207: New-RegistryKeyVolatile - No subkey detected in given registry key.
	70208: New-RegistryKeyVolatile - Failed to delete existing registry key.
	70209: New-RegistryKeyVolatile - The key already exists, use -DeleteIfExist switch to delete and recreate it (an empty key) volatile.
	70210: New-RegistryKeyVolatile - Unable to detect target registry hive in key.
	70211: New-RegistryKeyVolatile - Failed to create volatile registry key.

	Author:  Leonardo Franco Maragna
	Version: 1.0
	Date:    2023/02/08
#>
[CmdletBinding()]
Param (
)

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Variables: Extension Info
$VolatilePathsExtName = "VolatilePathsExtension"
$VolatilePathsExtScriptFriendlyName = "Volatile Paths Extension"
$VolatilePathsExtScriptVersion = "1.0"
$VolatilePathsExtScriptDate = "2023/02/08"
$VolatilePathsExtSubfolder = "PSADT.VolatilePaths"
$VolatilePathsExtConfigFileName = "VolatilePathsConfig.xml"
$VolatilePathsExtCustomTypesName = "VolatilePathsExtension.cs"

## Variables: Volatile Paths Script Dependency Files
[IO.FileInfo]$dirVolatilePathsExtFiles = Join-Path -Path $scriptRoot -ChildPath $VolatilePathsExtSubfolder
[IO.FileInfo]$VolatilePathsConfigFile = Join-Path -Path $dirVolatilePathsExtFiles -ChildPath $VolatilePathsExtConfigFileName
[IO.FileInfo]$VolatilePathsCustomTypesSourceCode = Join-Path -Path $dirVolatilePathsExtFiles -ChildPath $VolatilePathsExtCustomTypesName
if (-not $VolatilePathsConfigFile.Exists) { throw "$($VolatilePathsExtScriptFriendlyName) XML configuration file [$VolatilePathsConfigFile] not found." }
if (-not $VolatilePathsCustomTypesSourceCode.Exists) { throw "$($VolatilePathsExtScriptFriendlyName) custom types source code file [$VolatilePathsCustomTypesSourceCode] not found." }

## Import variables from XML configuration file
[Xml.XmlDocument]$xmlVolatilePathsConfigFile = Get-Content -LiteralPath $VolatilePathsConfigFile -Encoding UTF8
[Xml.XmlElement]$xmlVolatilePathsConfig = $xmlVolatilePathsConfigFile.VolatilePaths_Config

#  Get Config File Details
[Xml.XmlElement]$configVolatilePathsConfigDetails = $xmlVolatilePathsConfig.Config_File

#  Check compatibility version
$configVolatilePathsConfigVersion = [string]$configVolatilePathsConfigDetails.Config_Version
#$configMSIZapConfigDate = [string]$configMSIZapConfigDetails.Config_Date

try {
	if ([version]$VolatilePathsExtScriptVersion -ne [version]$configVolatilePathsConfigVersion) {
		Write-Log -Message "The $($VolatilePathsExtScriptFriendlyName) version [$([version]$VolatilePathsExtScriptVersion)] is not the same as the $($VolatilePathsExtConfigFileName) version [$([version]$configVolatilePathsConfigVersion)]. Problems may occurs." -Severity 2 -Source ${CmdletName}
	}
}
catch {}

#  Get Volatile Paths General Options
[Xml.XmlElement]$xmlVolatilePathsOptions = $xmlVolatilePathsConfig.VolatilePaths_Options
$configVolatilePathsGeneralOptions = [PSCustomObject]@{
	ExitScriptOnError = Invoke-Expression -Command 'try { [boolean]::Parse([string]($xmlVolatilePathsOptions.ExitScriptOnError)) } catch { $false }'
}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function New-PendingFileRenameOperation
Function New-PendingFileRenameOperation {
	<#
	.SYNOPSIS
		Queue a file or folder to be moved (renamed) or deleted after reboot by calling the native method.
	.DESCRIPTION
		Queue a file or folder to be moved (renamed) or deleted after reboot by calling the native method.
	.PARAMETER Path
		Fully qualified path name of the source file or directory.
	.PARAMETER DestinationPath
		fully qualified path name of the destination file or directory.
	.PARAMETER ReplaceExisting
		If specified and DestinationPath already exists, the original content will be overwritten.
	.PARAMETER ContinueOnError
		Continue if an error is encountered. Default is: $true.
	.PARAMETER DisableFunctionLogging
		Disables logging messages to the script log file.
	.INPUTS
		None
		You cannot pipe objects to this function.
	.OUTPUTS
		None
		Returns $true if the operation could be done.
	.EXAMPLE
		New-PendingFileRenameOperation -Path 'C:\Temp\file.txt' -DestinationPath 'C:\Temp\newfile.txt' -ReplaceExisting
	.NOTES
		This is an internal script function and should typically not be called directly.
		Author: Leonardo Franco Maragna
		Part of Volatile Paths Extension
	.LINK
		https://github.com/LFM8787/PSADT.VolatilePaths
		http://psappdeploytoolkit.com
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[IO.FileInfo]$Path,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[IO.FileInfo]$DestinationPath,
		[switch]$ReplaceExisting,
		[Parameter(Mandatory = $false)]
		[boolean]$ContinueOnError = $true,
		[switch]$DisableFunctionLogging
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

		## Force function logging if debugging
		if ($configToolkitLogDebugMessage) { $DisableFunctionLogging = $false }
	}
	Process {
		## Bypass if no Admin rights
		if ($PSBoundParameters.ContainsKey("DestinationPath")) {
			if (-not $IsAdmin) {
				Write-Log -Message "Administrative rights are needed to register movement (rename) of path [$Path] to [$DestinationPath] after reboot." -Severity 2 -Source ${CmdletName}
				if (-not $ContinueOnError) {
					if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70201 }
					throw "Administrative rights are needed to register movement (rename) of path [$Path] to [$DestinationPath] after reboot."
				}
				return $false
			}
		}
		else {
			if (-not $IsAdmin) {
				Write-Log -Message "Administrative rights are needed to register delete of path [$Path] after reboot." -Severity 2 -Source ${CmdletName}
				if (-not $ContinueOnError) {
					if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70202 }
					throw "Administrative rights are needed to register delete of path [$Path] after reboot."
				}
				return $false
			}
		}

		## Define the necessary flags
		$MoveFileFlags = [PSADT.File+MoveFileFlags]::MOVEFILE_DELAY_UNTIL_REBOOT
	
		## Invoke kernel32 method
		try {
			if ($PSBoundParameters.ContainsKey("DestinationPath")) {
				##  Warns the user if either the source or destination does not has extension
				if ([IO.Path]::HasExtension($Path) -ne [IO.Path]::HasExtension($DestinationPath)) {
					Write-Log -Message "Either the source path [$Path] or the destination path [$DestinationPath] does not has extension, this could be an error." -Severity 2 -Source ${CmdletName}
				}
				
				if ($ReplaceExisting) {
					$MoveFileFlags = $MoveFileFlags -bor [PSADT.File+MoveFileFlags]::MOVEFILE_REPLACE_EXISTING
				}
	
				return [bool]::Parse([PSADT.File]::MoveFileEx($Path, $DestinationPath, $MoveFileFlags))
			}
			else {
				return [bool]::Parse([PSADT.File]::MoveFileEx($Path, [NullString]::Value, $MoveFileFlags))
			}
		}
		catch {
			return $false
		}
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion


#region Function Move-FileAfterReboot
Function Move-FileAfterReboot {
	<#
	.SYNOPSIS
		Queue a file to be moved (renamed) after reboot.
	.DESCRIPTION
		Queue a file to be moved (renamed) after reboot.
	.PARAMETER Path
		Fully qualified path name of the source file.
	.PARAMETER DestinationPath
		fully qualified path name of the destination file.
	.PARAMETER ReplaceExisting
		If specified and DestinationPath already exists, the original content will be overwritten.
	.PARAMETER ContinueOnError
		Continue if an error is encountered. Default is: $true.
	.PARAMETER DisableFunctionLogging
		Disables logging messages to the script log file.
	.INPUTS
		None
		You cannot pipe objects to this function.
	.OUTPUTS
		None
		Returns $true if the operation could be done.
	.EXAMPLE
		Move-FileAfterReboot -Path 'C:\Temp\file.txt' -DestinationPath 'C:\Temp\newfile.txt' -ReplaceExisting
	.NOTES
		Author: Leonardo Franco Maragna
		Part of Volatile Paths Extension
	.LINK
		https://github.com/LFM8787/PSADT.VolatilePaths
		http://psappdeploytoolkit.com
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[IO.FileInfo]$Path,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[IO.FileInfo]$DestinationPath,
		[switch]$ReplaceExisting,
		[Parameter(Mandatory = $false)]
		[boolean]$ContinueOnError = $true,
		[switch]$DisableFunctionLogging
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

		## Force function logging if debugging
		if ($configToolkitLogDebugMessage) { $DisableFunctionLogging = $false }
	}
	Process {
		## Warns the user if the source file does not exist
		if (-not $Path.Exists) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source file [$Path] does not exist." -Severity 2 -Source ${CmdletName} }
		}
		elseif (-not (Test-Path -Path $Path -PathType Leaf)) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source path given [$Path] does not seem to be a file." -Severity 2 -Source ${CmdletName} }
		}

		## Warns the user if the destination file exists
		if ($DestinationPath.Exists) {
			if (-not (Test-Path -Path $DestinationPath -PathType Leaf)) {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The destination path given [$DestinationPath] does not seem to be a file." -Severity 2 -Source ${CmdletName} }
			}
			
			if ($ReplaceExisting) {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The destination file [$DestinationPath] already exists, it will be overwritten." -Severity 2 -Source ${CmdletName} }
			}
			else {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The destination file [$DestinationPath] already exists, to overwrite it use the -ReplaceExisting switch." -Severity 2 -Source ${CmdletName} }
			}
		}

		## Call function and evaluate result
		[bool]$Result = New-PendingFileRenameOperation @PSBoundParameters

		if ($Result) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The file [$Path] will be automatically moved (renamed) to [$DestinationPath] after reboot." -Source ${CmdletName} }
		}
		else {
			Write-Log -Message "Failed to register movement (rename) of file [$Path] to [$DestinationPath] after reboot." -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70203 }
				throw "Failed to register movement (rename) of file [$Path] to [$DestinationPath] after reboot."
			}
		}

		return $Result
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion


#region Function Move-FolderAfterReboot
Function Move-FolderAfterReboot {
	<#
	.SYNOPSIS
		Queue a folder to be moved (renamed) after reboot.
	.DESCRIPTION
		Queue a folder to be moved (renamed) after reboot.
	.PARAMETER Path
		Fully qualified path name of the source folder.
	.PARAMETER DestinationPath
		fully qualified path name of the destination folder.
	.PARAMETER ReplaceExisting
		If specified and DestinationPath already exists, the original content will be overwritten.
	.PARAMETER ContinueOnError
		Continue if an error is encountered. Default is: $true.
	.PARAMETER DisableFunctionLogging
		Disables logging messages to the script log file.
	.INPUTS
		None
		You cannot pipe objects to this function.
	.OUTPUTS
		None
		Returns $true if the operation could be done.
	.EXAMPLE
		Move-FolderAfterReboot -Path 'C:\Temp' -DestinationPath 'C:\Temp_old' -ReplaceExisting
	.NOTES
		Author: Leonardo Franco Maragna
		Part of Volatile Paths Extension
	.LINK
		https://github.com/LFM8787/PSADT.VolatilePaths
		http://psappdeploytoolkit.com
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[IO.FileInfo]$Path,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[IO.FileInfo]$DestinationPath,
		[switch]$ReplaceExisting,
		[Parameter(Mandatory = $false)]
		[boolean]$ContinueOnError = $true,
		[switch]$DisableFunctionLogging
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

		## Force function logging if debugging
		if ($configToolkitLogDebugMessage) { $DisableFunctionLogging = $false }
	}
	Process {
		## Warns the user if the source folder does not exist
		if (-not $Path.Exists) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source folder [$Path] does not exist." -Severity 2 -Source ${CmdletName} }
		}
		elseif (-not (Test-Path -Path $Path -PathType Container)) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source path given [$Path] does not seem to be a folder." -Severity 2 -Source ${CmdletName} }
		}

		## Warns the user if the destination folder exists
		if ($DestinationPath.Exists) {
			if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The destination path given [$DestinationPath] does not seem to be a folder." -Severity 2 -Source ${CmdletName} }
			}

			if ($ReplaceExisting) {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The destination folder [$DestinationPath] already exists, it will be overwritten." -Severity 2 -Source ${CmdletName} }
			}
			else {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The destination folder [$DestinationPath] already exists, to overwrite it use the -ReplaceExisting switch." -Severity 2 -Source ${CmdletName} }
			}
		}
		
		## Call function and evaluate result
		[bool]$Result = New-PendingFileRenameOperation @PSBoundParameters

		if ($Result) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The folder [$Path] will be automatically moved (renamed) to [$DestinationPath] after reboot." -Source ${CmdletName} }
		}
		else {
			Write-Log -Message "Failed to register movement (rename) of folder [$Path] to [$DestinationPath] after reboot." -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70204 }
				throw "Failed to register movement (rename) of folder [$Path] to [$DestinationPath] after reboot."
			}
		}

		return $Result
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion


#region Function Remove-FileAfterReboot
Function Remove-FileAfterReboot {
	<#
	.SYNOPSIS
		Queue a file to be deleted after reboot.
	.DESCRIPTION
		Queue a file to be deleted after reboot.
	.PARAMETER Path
		Fully qualified path name of the file.
	.PARAMETER ContinueOnError
		Continue if an error is encountered. Default is: $true.
	.PARAMETER DisableFunctionLogging
		If specified disables logging messages to the script log file.
	.INPUTS
		None
		You cannot pipe objects to this function.
	.OUTPUTS
		None
		Returns $true if the operation could be done.
	.EXAMPLE
		Remove-FileAfterReboot -Path 'C:\Temp\file.txt'
	.NOTES
		Author: Leonardo Franco Maragna
		Part of Volatile Paths Extension
	.LINK
		https://github.com/LFM8787/PSADT.VolatilePaths
		http://psappdeploytoolkit.com
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[IO.FileInfo]$Path,
		[Parameter(Mandatory = $false)]
		[boolean]$ContinueOnError = $true,
		[switch]$DisableFunctionLogging
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

		## Force function logging if debugging
		if ($configToolkitLogDebugMessage) { $DisableFunctionLogging = $false }
	}
	Process {
		## Warns the user if the source file does not exist
		if (-not $Path.Exists) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source file [$Path] does not exist." -Severity 2 -Source ${CmdletName} }
		}
		elseif (-not (Test-Path -Path $Path -PathType Leaf)) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source path given [$Path] does not seem to be a file." -Severity 2 -Source ${CmdletName} }
		}

		## Call function and evaluate result
		[bool]$Result = New-PendingFileRenameOperation @PSBoundParameters

		if ($Result) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The file [$Path] will be automatically deleted after reboot." -Source ${CmdletName} }
		}
		else {
			Write-Log -Message "Failed to register delete of file [$Path] after reboot." -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70205 }
				throw "Failed to register delete of file [$Path] after reboot."
			}
		}

		return $Result
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion


#region Function Remove-FolderAfterReboot
Function Remove-FolderAfterReboot {
	<#
	.SYNOPSIS
		Queue a folder to be deleted after reboot.
	.DESCRIPTION
		Queue a folder to be deleted after reboot.
	.PARAMETER Path
		Fully qualified path name of the folder.
	.PARAMETER ContinueOnError
		Continue if an error is encountered. Default is: $true.
	.PARAMETER DisableFunctionLogging
		If specified disables logging messages to the script log file.
	.INPUTS
		None
		You cannot pipe objects to this function.
	.OUTPUTS
		None
		Returns $true if the operation could be done.
	.EXAMPLE
		Remove-FolderAfterReboot -Path 'C:\Temp'
	.NOTES
		Author: Leonardo Franco Maragna
		Part of Volatile Paths Extension
	.LINK
		https://github.com/LFM8787/PSADT.VolatilePaths
		http://psappdeploytoolkit.com
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[IO.FileInfo]$Path,
		[Parameter(Mandatory = $false)]
		[boolean]$ContinueOnError = $true,
		[switch]$DisableFunctionLogging
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

		## Force function logging if debugging
		if ($configToolkitLogDebugMessage) { $DisableFunctionLogging = $false }
	}
	Process {
		## Warns the user if the source file does not exist
		if (-not $Path.Exists) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source folder [$Path] does not exist." -Severity 2 -Source ${CmdletName} }
		}
		elseif (-not (Test-Path -Path $Path -PathType Container)) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The source path given [$Path] does not seem to be a folder." -Severity 2 -Source ${CmdletName} }
		}

		## Call function and evaluate result
		[bool]$Result = New-PendingFileRenameOperation @PSBoundParameters

		if ($Result) {
			if (-not ($DisableFunctionLogging)) { Write-Log -Message "The folder [$Path] will be automatically deleted after reboot." -Source ${CmdletName} }
		}
		else {
			Write-Log -Message "Failed to register delete of folder [$Path] after reboot." -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70206 }
				throw "Failed to register delete of folder [$Path] after reboot."
			}
		}

		return $Result
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion


#region Function New-RegistryKeyVolatile
Function New-RegistryKeyVolatile {
	<#
	.SYNOPSIS
		Creates a volatile registry key that will be deleted when registry unloads (logoff/shutdown).
	.DESCRIPTION
		Creates a volatile registry key that will be deleted when registry unloads (logoff/shutdown).
	.PARAMETER Key
		The registry key path.
	.PARAMETER SID
		The security identifier (SID) for a user. Specifying this parameter will convert a HKEY_CURRENT_USER registry key to the HKEY_USERS\$SID format.
		Specify this parameter from the Invoke-HKCURegistrySettingsForAllUsers function to read/edit HKCU registry settings for all users on the system.
	.PARAMETER DeleteIfExist
		Deletes the existing registry key and creates a volatile empty one.
	.PARAMETER ContinueOnError
		Continue if an error is encountered. Default is: $true.
	.PARAMETER DisableFunctionLogging
		If specified disables logging messages to the script log file.
	.INPUTS
		None
		You cannot pipe objects to this function.
	.OUTPUTS
		None
		This function does not generate any output.
	.EXAMPLE
		New-RegistryKeyVolatile -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Application_Temp'
	.NOTES
		Author: Leonardo Franco Maragna
		Part of Volatile Paths Extension
	.LINK
		https://github.com/LFM8787/PSADT.VolatilePaths
		http://psappdeploytoolkit.com
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullorEmpty()]
		[string]$Key,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$SID,
		[switch]$DeleteIfExist,
		[Parameter(Mandatory = $false)]
		[boolean]$ContinueOnError = $true,
		[switch]$DisableFunctionLogging
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

		## Force function logging if debugging
		if ($configToolkitLogDebugMessage) { $DisableFunctionLogging = $false }
	}
	Process {
		## If the SID variable is specified, then convert all HKEY_CURRENT_USER key's to HKEY_USERS\$SID
		if ($PSBoundParameters.ContainsKey("SID")) {
			[string]$Key = Convert-RegistryPath -Key $Key -SID $SID
		}
		else {
			[string]$Key = Convert-RegistryPath -Key $Key
		}

		## Validate the beginning of the key and try to obtain the subtree
		$ValidKeyRegexPattern = "(?<=(Registry::|))HKEY_[\w]*(?=[\\])"
		$Key | Select-String -Pattern $ValidKeyRegexPattern -AllMatches | ForEach-Object { $KeySubTree = @($_.matches.value) }

		## Validate the subkey using the previously validated subtree
		$SubKeyRegexPattern = "(?<=$($KeySubTree)[:]{0,1}[\\]).*"
		$Key | Select-String -Pattern $SubKeyRegexPattern -AllMatches | ForEach-Object { [string]$SubKey = @($_.matches.value) }

		if ([string]::IsNullOrWhiteSpace($KeySubTree) -or [string]::IsNullOrWhiteSpace($SubKey)) {
			Write-Log -Message "No subkey detected in given registry key [$Key]." -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70207 }
				throw "No subkey detected in given registry key [$Key]."
			}
			return
		}
		else {
			#  Delete if exists
			if (Test-Path -LiteralPath $Key -ErrorAction SilentlyContinue) {
				if ($DeleteIfExist) {
					Write-Log -Message "The registry key [$Key] already exists, it will be deleted." -Severity 2 -Source ${CmdletName}
					try {
						Remove-RegistryKey -Key $Key -Recurse -ContinueOnError $ContinueOnError
					}
					catch {
						Write-Log -Message "Failed to delete existing registry key [$Key].`r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
						if (-not $ContinueOnError) {
							if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70208 }
							throw "Failed to delete existing registry key [$Key]: $($_.Exception.Message)"
						}
						return
					}
				}
				else {
					Write-Log -Message "The key [$Key] already exists, use -DeleteIfExist switch to delete and recreate an empty volatile key." -Severity 3 -Source ${CmdletName}
					if (-not $ContinueOnError) {
						if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70209 }
						throw "The key [$Key] already exists, use -DeleteIfExist switch to delete and recreate an empty volatile key."
					}
					return
				}
			}
		}

		## Expand the previously validated subtree
		$RegistryHive = switch ($KeySubTree) {
			"HKEY_LOCAL_MACHINE" { "LocalMachine" }
			"HKEY_CURRENT_USER" { "CurrentUser" }
			"HKEY_USERS" { "Users" }
			"HKEY_CLASSES_ROOT" { "ClassesRoot" }
			"HKEY_CURRENT_CONFIG" { "CurrentConfig" }
			Default { $null }
		}

		if ($null -eq $RegistryHive) {
			Write-Log -Message "Unable to detect target registry hive in key [$Key]." -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70210 }
				throw "Unable to detect target registry hive in key [$Key]."
			}
			return
		}

		## Try to create volatile subkey
		try {
			$RegistryBaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($RegistryHive, "Default")
			$null = $RegistryBaseKey.CreateSubKey($SubKey, $true , [Microsoft.Win32.RegistryOptions]::Volatile)

			if ($? -and (Test-Path -LiteralPath $Key -ErrorAction SilentlyContinue)) {
				if (-not ($DisableFunctionLogging)) { Write-Log -Message "The key [$Key] was successfully created as volatile." -Source ${CmdletName} }
			}
		}
		catch {
			Write-Log -Message "Failed to create volatile registry key [$Key].`r`n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
			if (-not $ContinueOnError) {
				if ($configVolatilePathsGeneralOptions.ExitScriptOnError) { Exit-Script -ExitCode 70211 }
				throw "Failed to create volatile registry key [$Key]: $($_.Exception.Message)"
			}
			return
		}
	}
	End {
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
}
#endregion

#endregion
##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================
#region ScriptBody

if ($scriptParentPath) {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $VolatilePathsExtName
}
else {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $VolatilePathsExtName
}

## Add the custom types required for the toolkit
if (-not ([Management.Automation.PSTypeName]"PSADT.File").Type) {
	Add-Type -Path $VolatilePathsCustomTypesSourceCode -ReferencedAssemblies $ReferencedAssemblies -IgnoreWarnings -ErrorAction Stop
}

#endregion
##*===============================================
##* END SCRIPT BODY
##*===============================================