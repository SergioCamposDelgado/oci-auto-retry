<#
.SYNOPSIS
    Trigger GitHub Actions repository_dispatch event for oci-auto-retry.

.EXAMPLE
    .\scripts\trigger.ps1 -Owner "your-username" -Token "ghp_yourToken"
#>
param (
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo = "oci-auto-retry",

    [Parameter(Mandatory = $true)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$EventType = "lanzar-intento-oci"
)

$uri = "https://api.github.com/repos/$Owner/$Repo/dispatches"
$headers = @{
    "Accept"               = "application/vnd.github+json"
    "Authorization"        = "Bearer $Token"
    "X-GitHub-Api-Version" = "2022-11-28"
}
$body = @{
    "event_type" = $EventType
} | ConvertTo-Json

Write-Host "Triggering event '$EventType' on $Owner/$Repo..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
    Write-Host "✅ Dispatch triggered successfully!" -ForegroundColor Green
}
catch {
    Write-Error "❌ Error triggering dispatch: $_"
}
