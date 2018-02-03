[CmdletBinding()]
param (
	[Parameter(Mandatory=$true)]
	[string] $CommandName,

	# Only return the path to the command.
	[alias('b')]
	[switch] $Bare,

	# Also search in modules that in PSModulePath and may not be imported yet.
	[switch] $ListAvailable
)

Add-Type -Path "$PsScriptRoot\Fsharp.Core.dll"
Add-Type -Path "$PsScriptRoot\psparsing.dll"

function Get-PsFunction
{
    <#
    .Synopsis
        Find function/filter definition location.
    .Example
        Get-PsFunction Get-PsFunction
    #>
    [CmdletBinding()]
    param (
		[parameter(mandatory=$true)]
		[string] $Name,
       	[string] $Path = ((Get-Location).ProviderPath),
		[switch] $Regex
        )
   	[psparsing]::FindFunctions($Path, $true, $Name, $Regex)
}

function Get-PSProfile {
	<#
	.Synopsis
		Shows all profile files that PowerShell supports.
	#>
	$Profile.PSExtended.PSObject.Properties | foreach {
			[PsCustomObject] @{
				Name = $_.Name
				Path = $_.Value
				Exists = (Test-Path -Path $_.Value -PathType Leaf)
			}
	}
}

Function Get-Function
{
	<#
	.Synopsis
		Extracts function information using PSParser from piped in text
		and returns function name and line number in a custom object.
	.Example
        cd "$($env:myhome)\data\scripts"
		dir *.ps1,*.psm1 | Get-Function
	.Example
		dir -r *.ps1,*.psm1 | Get-Function | Where { $_.FunctionName = 'Foo' }
	.Example
		$parser::Tokenize('dir; . "$b\test.ps1"; dir', [ref]$null)
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[string] $Path,

		[Parameter(Position=0)]
		[string] $FunctionName
		)

	begin {
	 	$parser  = [System.Management.Automation.PSParser]
	}

	process {
		$Content = Get-Content $Path | Out-String
		# remove NewLine token so that "function`n foo" will still work
		$tokens  = $parser::Tokenize($Content, [ref] $null) | where { $_.Type -ne 'NewLine' }
		$count   = $tokens.Count

		for ($idx=0; $idx -lt $count; $idx += 1) {
			if (($tokens[$idx].Type -eq 'Keyword') -and (($tokens[$idx].Content -eq 'function') -or ($tokens[$idx].Content -eq 'filter'))) {
				$targetToken = $tokens[$idx+1]
				$funcname = $targetToken.Content
				if (!$FunctionName -or ($FunctionName -eq $funcname)) {
					[PsCustomObject] @{
						FunctionName = $funcname
						IsFilter = ($tokens[$idx].Content -eq 'filter')
						Path = $Path
						Line = $targetToken.StartLine
					}
				}
			}
	    }
	}
}

function Get-Coalesce([scriptblock[]] $blocks) {
	for ($i = 0; $i -lt $blocks.Length; $i++) {
		$ret = & $blocks[$i]
		if ($ret) {
			return $ret
		}
	}
}

function IsModule($cmd) {
	Write-Verbose "Detect if $cmd is from a module"
	if ($cmd.Module -and $cmd.Module.Path) {
		$modulePath = Split-Path $cmd.Module.Path
		Write-Verbose "Calling Get-PsFunction to search for function $($cmd.Name) in $modulePath"
		Get-PsFunction $cmd.Name $modulePath | Add-Member -PassThru -Force ModuleName $cmd.Module.Name
	}
}

function IsFunctionInProfile($cmd) {
	Write-Verbose "Detect if $cmd is in function defined in profile"
	if (($cmd.CommandType -eq 'Function') -or ($cmd.CommandType -eq 'Filter')) {
		Get-PsProfile | where { $_.Exists } | Get-Function $cmd.Name
	}
}

function IsFunctionInMemory($cmd) {
	Write-Verbose "Detect if $cmd is a function defined in memory"
	if ($cmd.CommandType -eq 'Function' -and $cmd.Module -eq $null) {
		Write-Warning "$cmd is a function defined in memory"
	}
}

function IsAlias($cmd) {
	Write-Verbose "Detect if $cmd is alias"
	if ($cmd.CommandType -eq 'Alias') {
		Write-Host "$cmd is alias to $($cmd.Definition)"
		return IsCommand $cmd.ResolvedCommand
	}
}

function IsCmdlet($cmd) {
	Write-Verbose "Detect if $cmd is cmdlet"
	if ($cmd.CommandType -eq 'Cmdlet') {
		Write-Verbose "$cmd is cmdlet"
		$cmd | Add-Member -PassThru -Force Path $cmd.DLL
	}
}

function IsFileInPath($cmd) {
	$pathlist = $env:Path -split ';'
	foreach($path in $pathlist) {
		if (Test-Path "$path\$cmd") {
			Write-Verbose "$cmd is in path"
			return [PSCustomObject] @{
                CommandType = 'PATH'
                Path = "$path\$cmd"
            }
		}
	}
}

function IsCommand($cmd) {
	return Get-Coalesce @(
		{if ($cmd.Path) { $cmd } }
		{IsAlias $cmd}
		{IsCmdlet $cmd}
		{IsModule $cmd}
		{IsFunctionInProfile $cmd}
		{IsFunctionInMemory $cmd}
	)
}

$result = $(
	If (Test-Path $CommandName -PathType Leaf) {
		[PSCustomObject] @{Path=$CommandName}
	} else {
		# something strange: initially I was not adding "-All" below and it works correct to return both
		# connect.exe (from gnu win32) and my connect.py; however when I call this which.ps1 from Edit-Script
		# in module utils, it is only returning connect.exe if I didn't pass "-All".
		Get-Command $CommandName -All 2>&1 | foreach {
			if ($_ -is [Management.Automation.ErrorRecord]) {
				Get-CoalEsce @(
					{ IsFileInPath $CommandName }
					{ Write-Warning "$_" }
				)
			} else {
				IsCommand $_
			}
		}
	}
)

if ($Bare) {
	Get-Coalesce @(
		{ $result.Path }
		{ $result.Definition }
	)
} else {
	$result
}
