# PSADT.VolatilePaths
Extension for PowerShell App Deployment Toolkit to create volatile registry keys and move/delete files/folder on reboot using native methods.

## Features
- Queues a file/folder to be deleted on reboot.
- Queues a file/folder to be moved (renamed) on reboot.
- Overwrites target file/folder if specified
- Creates volatile registry keys that exists only in RAM loaded registry.
- Native methods used to perform the tasks.
- Warns the user if the source folder is a special folder
- *ContinueOnError* and *ExitScriptOnError* support.

## Disclaimer
```diff
- Test the functions before production.
- Make a backup before applying.
- Check the config file options description.
- Run AppDeployToolkitHelp.ps1 for more help and parameter descriptions.
```

## Functions
* **Move-FileAfterReboot** - Queue a file to be moved (renamed) after reboot.
* **Move-FolderAfterReboot** - Queue a folder to be moved (renamed) after reboot.
* **Remove-FileAfterReboot** - Queue a file to be deleted after reboot.
* **Remove-FolderAfterReboot** - Queue a folder to be deleted after reboot.
* **New-RegistryKeyVolatile** - Creates a volatile registry key that will be deleted when registry unloads (logoff/shutdown).

## Usage
```PowerShell
# Moves or deletes a file after reboot
Move-FileAfterReboot -Path 'C:\Temp\file.txt' -DestinationPath 'C:\Temp\newfile.txt' -ReplaceExisting
Remove-FileAfterReboot -Path 'C:\Temp\file.txt'

# Moves or deletes a folder after reboot
Move-FolderAfterReboot -Path 'C:\Temp' -DestinationPath 'C:\Temp_old' -ReplaceExisting
Remove-FolderAfterReboot -Path 'C:\Temp'

# Creates a voletile registry subkey
New-RegistryKeyVolatile -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\Application_Temp'
```

## Internal functions
`This set of functions are internals and are not designed to be called directly`
* **New-PendingFileRenameOperation** - Queue a file or folder to be moved (renamed) or deleted after reboot by calling the native method.

## Extension Exit Codes
|Exit Code|Function|Exit Code Detail|
|:----------:|:--------------------|:-|
|70201|New-PendingFileRenameOperation|Administrative rights are needed to register movement (rename) after reboot.|
|70202|New-PendingFileRenameOperation|Administrative rights are needed to register delete after reboot.|
|70212|New-PendingFileRenameOperation|The source folder is included in the system SpecialFolder enumeration. Manipulation could compromise system stability.|
|70203|Move-FileAfterReboot|Failed to register movement (rename) of file after reboot.|
|70204|Move-FolderAfterReboot|Failed to register movement (rename) of folder after reboot.|
|70205|Remove-FileAfterReboot|Failed to register delete of file after reboot.|
|70206|Remove-FolderAfterReboot|Failed to register delete of folder after reboot.|
|70207|New-RegistryKeyVolatile|No subkey detected in given registry key.|
|70208|New-RegistryKeyVolatile|Failed to delete existing registry key.|
|70209|New-RegistryKeyVolatile|The key already exists, use -DeleteIfExist switch to delete and recreate it (an empty key) volatile.|
|70210|New-RegistryKeyVolatile|Unable to detect target registry hive in key.|
|70211|New-RegistryKeyVolatile|Failed to create volatile registry key.|

## How to Install
#### 1. Download and extract into Toolkit folder.
#### 2. Edit *AppDeployToolkitExtensions.ps1* file and add the following lines.
#### 3. Create an empty array (only once if multiple extensions):
```PowerShell
## Variables: Extensions to load
$ExtensionToLoad = @()
```
#### 4. Add Extension Path and Script filename (repeat for multiple extensions):
```PowerShell
$ExtensionToLoad += [PSCustomObject]@{
	Path   = "PSADT.VolatilePaths"
	Script = "VolatilePathsExtension.ps1"
}
```
#### 5. Complete with the remaining code to load the extension (only once if multiple extensions):
```PowerShell
## Loading extensions
foreach ($Extension in $ExtensionToLoad) {
	$ExtensionPath = $null
	if ($Extension.Path) {
		[IO.FileInfo]$ExtensionPath = Join-Path -Path $scriptRoot -ChildPath $Extension.Path | Join-Path -ChildPath $Extension.Script
	}
	else {
		[IO.FileInfo]$ExtensionPath = Join-Path -Path $scriptRoot -ChildPath $Extension.Script
	}
	if ($ExtensionPath.Exists) {
		try {
			. $ExtensionPath
		}
		catch {
			Write-Log -Message "An error occurred while trying to load the extension file [$($ExtensionPath)].`r`n$(Resolve-Error)" -Severity 3 -Source $appDeployToolkitExtName
		}
	}
	else {
		Write-Log -Message "Unable to locate the extension file [$($ExtensionPath)]." -Severity 2 -Source $appDeployToolkitExtName
	}
}
```

## Requirements
* Powershell 5.1+
* PSAppDeployToolkit 3.8.4+

## External Links
* [PowerShell App Deployment Toolkit](https://psappdeploytoolkit.com/)
* [MoveFileExA function (winbase.h) - Win32 App | Microsoft Learn](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexa)
* [RegistryKey.CreateSubKey Method - Microsoft.Win32 | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registrykey.createsubkey)