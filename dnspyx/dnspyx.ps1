<#
.Example
	Get-Command Get-Process | dnspyx
.Example
	$x.GetType().Assembly.Location | dnspyx
.Notes
	Tag type: 'T','F','P','E','M'
#>
[CmdletBinding(DefaultParameterSetName='Path')]
param (
	[Parameter(Position=0, ParameterSetName='Path', ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
	[Alias('Definition')]
	[Alias('FullName')]
	[string] $Path,

	[Parameter(ParameterSetName='Member', ValueFromPipeline=$true)]
	[System.Reflection.MemberInfo] $Member,

	[Parameter(ParameterSetName='Cmdlet', ValueFromPipeline=$true)]
	[Management.Automation.CommandInfo] $Cmdlet,

	[Parameter(ParameterSetName='win32_service', ValueFromPipeline=$true)]
	[System.Management.ManagementObject] $Service
)

process {
	Write-Verbose "ParameterSetName: $($PsCmdlet.ParameterSetName)"
	$NavigateTo = $null
	switch ($PsCmdlet.ParameterSetName) {
		'Cmdlet' {
			if ($Cmdlet.CommandType -eq 'Application') {
				$Path = $Cmdlet.Definition
				$NavigateTo = $null
			} else {
				while ($Cmdlet.CommandType -eq "Alias") {
					$Cmdlet = Get-Command ($Cmdlet.definition)
				}

				$NavigateTo = 'T:' + $Cmdlet.ImplementingType
				$Path = $Cmdlet.DLL
			}
		}
		'win32_service' {
			$Path = $Service.PathName
		}
		'Member' {
			if ($Member -isnot [type]) {
				$Type = $Member.ReflectedType
			} else {
				$Type = $Member
			}

			$Path = $Type.Assembly.Location
			$NavigateTo = 'T:' + $Type.FullName
		}
		'Path' {
			$Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
		}
	}

	$a = @($Path)
	if ($NavigateTo) {
		$a += @('--select', $NavigateTo) # dnspy latest
	}

	Write-Host "$($a -join ' ')"
	& dnspy @a
}
