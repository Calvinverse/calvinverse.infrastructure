[CmdletBinding()]
param(
    [string] $vaultPath = 'vault',

    [string] $vaultServerAddress,

    [ValidateSet(
        'role.system.linux',
        'role.system.windows',
        'role.artefacts.http',
        'role.build.agent.windows',
        'role.build.master',
        'role.metrics.dashboards',
        'role.metrics.snmp'
    )]
    [string] $role = 'role.system.linux',

    [string] $machineName,

    [string] $consulPort = '8500',

    [string] $consulServerAddress = $( throw 'Please specify the IP address for the consul server' )
)

$ErrorActionPreference = 'Stop'

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'helpers.ps1')

$createToken = @(
    '-force',
    '-wrap-ttl=5m',
    '-format=json',
    "auth/token/create/$($role)"
)
$returnValue = Invoke-Vault `
    -vaultPath $vaultPath `
    -vaultServerAddress $vaultServerAddress `
    -command 'write' `
    -arguments $createToken

$singleLine = $returnValue | Out-String
$json = ConvertFrom-Json -InputObject $singleLine

# Write token for machine to consul kv
# auth/services/templates/<MACHINE_NAME>/secrets
$key = "auth/services/templates/$($machineName.ToLowerInvariant())/secrets"
$value = $json.wrap_info.token

Write-Output "Writing k-v with key: $($key) - value: $($value) ... "

$webClient = New-Object System.Net.WebClient
try
{
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($value)

    $url = "http://$($consulServerAddress):$($consulPort)/v1/kv/$($key)"
    $responseBytes = $webClient.UploadData($url, "PUT", $bytes)
    $response = [System.Text.Encoding]::ASCII.GetString($responseBytes)
    Write-Output "Wrote k-v with key: $($key) - value: $($value). Response: $($response)"
}
finally
{
    $webClient.Dispose()
}
