#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create the first admin account via API

.DESCRIPTION
    This script creates the first admin account using the Open-WebUI API.
    Useful when the signup form is not visible on the web interface.

.PARAMETER Email
    Admin email address (default: admin@kubecon.demo)

.PARAMETER Password
    Admin password (default: KubeConAdmin2025!)

.PARAMETER Name
    Admin full name (default: Admin)

.PARAMETER Namespace
    Kubernetes namespace where Open-WebUI is deployed (default: ollama)

.EXAMPLE
    .\scripts\create-admin.ps1

.EXAMPLE
    .\scripts\create-admin.ps1 -Email "myemail@company.com" -Password "MySecurePass123!" -Name "John Doe"
#>

param(
    [Parameter()]
    [string]$Email = "admin@kubecon.demo",

    [Parameter()]
    [string]$Password = "KubeConAdmin2025!",

    [Parameter()]
    [string]$Name = "Admin",

    [Parameter()]
    [string]$Namespace = "ollama"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Create First Admin Account" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get WebUI service IP
Write-Host "Getting WebUI URL..." -ForegroundColor Yellow
$webUIIP = kubectl get svc -n $Namespace open-webui -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>&1

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($webUIIP)) {
    Write-Host "  [ERROR] Could not get WebUI service IP" -ForegroundColor Red
    Write-Host "  Make sure the service is running in namespace: $Namespace" -ForegroundColor Yellow
    exit 1
}

$webUIURL = "http://$webUIIP"
Write-Host "  WebUI URL: $webUIURL" -ForegroundColor Green

# Prepare signup data
$signupData = @{
    email = $Email
    password = $Password
    name = $Name
} | ConvertTo-Json

Write-Host "`nCreating admin account..." -ForegroundColor Yellow
Write-Host "  Email: $Email" -ForegroundColor White
Write-Host "  Name: $Name" -ForegroundColor White

# Call the signup API
try {
    $response = Invoke-RestMethod -Uri "$webUIURL/api/v1/auths/signup" `
        -Method Post `
        -ContentType "application/json" `
        -Body $signupData `
        -ErrorAction Stop

    if ($response.id) {
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "Admin Account Created Successfully!" -ForegroundColor Green
        Write-Host "========================================`n" -ForegroundColor Green

        Write-Host "Account Details:" -ForegroundColor Cyan
        Write-Host "  User ID: $($response.id)" -ForegroundColor White
        Write-Host "  Email: $($response.email)" -ForegroundColor White
        Write-Host "  Name: $($response.name)" -ForegroundColor White
        Write-Host "  Role: $($response.role)" -ForegroundColor Green

        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "  1. Open: $webUIURL" -ForegroundColor White
        Write-Host "  2. Login with:" -ForegroundColor White
        Write-Host "     Email: $Email" -ForegroundColor Cyan
        Write-Host "     Password: <the password you provided>" -ForegroundColor Cyan
        Write-Host "  3. Go to Admin Panel to approve new signups" -ForegroundColor White
        Write-Host "  4. Share URL with visitors for them to sign up`n" -ForegroundColor White

        # Save credentials to file for reference
        $credFile = "admin-credentials.txt"
        @"
Open-WebUI Admin Credentials
========================================
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

WebUI URL: $webUIURL
Email: $Email
Password: $Password
Name: $Name
Role: $($response.role)

Login URL: $webUIURL
Admin Panel: $webUIURL (click profile icon → Admin Panel)

IMPORTANT: Keep these credentials secure!
Delete this file after saving credentials elsewhere.
"@ | Out-File -FilePath $credFile -Encoding UTF8

        Write-Host "Credentials saved to: $credFile" -ForegroundColor Yellow
        Write-Host "Remember to delete this file after securing credentials!`n" -ForegroundColor Yellow

    } else {
        Write-Host "`n[ERROR] Unexpected response from API" -ForegroundColor Red
        Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor Gray
        exit 1
    }

} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = ""

    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        $reader.Close()
    }

    Write-Host "`n[ERROR] Failed to create admin account" -ForegroundColor Red

    if ($statusCode -eq 400) {
        Write-Host "  Reason: User might already exist" -ForegroundColor Yellow
        Write-Host "  Try logging in with existing credentials" -ForegroundColor Yellow
        Write-Host "  Or use a different email address`n" -ForegroundColor Yellow

        # Try to get existing users count
        try {
            $usersCheck = Invoke-RestMethod -Uri "$webUIURL/api/v1/auths/" -Method Get -ErrorAction SilentlyContinue
            Write-Host "  Existing users found in database" -ForegroundColor Gray
        } catch {}

    } elseif ($statusCode -eq 403) {
        Write-Host "  Reason: Signup might be disabled" -ForegroundColor Yellow
        Write-Host "  Check ENABLE_SIGNUP environment variable" -ForegroundColor Yellow
    } else {
        Write-Host "  Status Code: $statusCode" -ForegroundColor Gray
        if ($errorBody) {
            Write-Host "  Error: $errorBody" -ForegroundColor Gray
        }
    }

    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check if WebUI is accessible: $webUIURL" -ForegroundColor White
    Write-Host "  2. Verify ENABLE_SIGNUP=True:" -ForegroundColor White
    Write-Host "     kubectl exec -n $Namespace <pod> -- printenv ENABLE_SIGNUP" -ForegroundColor Gray
    Write-Host "  3. Check WebUI logs:" -ForegroundColor White
    Write-Host "     kubectl logs -n $Namespace -l app=open-webui --tail=50" -ForegroundColor Gray
    Write-Host "  4. Try the fix-signup script:" -ForegroundColor White
    Write-Host "     .\scripts\fix-signup.ps1`n" -ForegroundColor Gray

    exit 1
}
