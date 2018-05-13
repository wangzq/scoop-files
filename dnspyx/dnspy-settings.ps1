[CmdletBinding()]
param (
	[switch] $Force
	)

$dir = "$env:appdata\dnspy"
if (!(Test-Path $dir)) { mkdir $dir | Out-Null }
$file = "$dir\dnspy.xml"
if ((Test-Path $file) -and !$Force) {
	if(!$PSCmdlet.ShouldContinue("Are you REALLY sure you want to overwrite ${file}?", "Confirmation")) {
		return	
	}
}

Invoke-WebRequest https://raw.githubusercontent.com/wangzq/scoop-files/master/dnspyx/dnSpy.xml -OutFile $file
