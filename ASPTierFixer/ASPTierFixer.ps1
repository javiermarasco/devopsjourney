param (
        [switch]$management,
        [string]$ResourceGroupName,
        [string]$SubscriptionId
    )
    
Login-AzAccount

Select-AzSubscription -subscriptionid $SubscriptionId

# Obtain location of resource group

$ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName

# Create a temporal resource group

New-AzResourceGroup -Name "TemporalASPFix" -Location "centralus"

# Move all your resources to this temporal resource group (Except for ASP, app services, certificates and slots)
$ResourcesInResourceGroup = Get-AzResource

$ResouecesToMove = $ResourcesInResourceGroup | Where-Object `
{`
    $_.ResourceType -NotIn 'Microsoft.Web/serverFarms', 'Microsoft.Web/sites', 'Microsoft.Web/slots', 'Microsoft.Web/certificates' -and `
    $_.ResourceGroupName -eq $ResourceGroupName `
}

Move-AzResource -DestinationResourceGroupName "TemporalASPFix" -ResourceId $ResouecesToMove.ResourceId -Force


# Delete the certificates, app services and then ASP
$AppServicesToDelete = $ResourcesInResourceGroup | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName -and $_.ResourceType -eq 'Microsoft.Web/sites'}
foreach ($AppService in $AppServicesToDelete) {
    Remove-AzWebApp -ResourceGroupName $ResourceGroupName -Name $AppService.Name -Force
}

$AppServicePlansToDelete = $ResourcesInResourceGroup | Where-Object {$_.ResourceGroupName -eq $ResourceGroupName -and $_.ResourceType -eq 'Microsoft.Web/serverFarms'}
foreach ($AppServicePlan in $AppServicePlansToDelete) {
    Remove-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlan.Name -Force
}

# Delete the resource group
Remove-AzResourceGroup -Name $ResourceGroupName -Force

# Create the resource group again (with the same name)
New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroup.Location

# Create a temporal ASP as PremiumV2
New-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name "TemporalAppServicePlan" -Location $ResourceGroup.Location -Tier PremiumV2 

# Move all your resources back to this newly created resource group. We need to get the resources again as their Id has changed due to the movement
$ResourcesInResourceGroup = Get-AzResource

$ResouecesToMove = $ResourcesInResourceGroup | Where-Object `
{`
    $_.ResourceType -NotIn 'Microsoft.Web/serverFarms', 'Microsoft.Web/sites', 'Microsoft.Web/slots', 'Microsoft.Web/certificates' -and `
    $_.ResourceGroupName -eq "TemporalASPFix" `
}
Move-AzResource -DestinationResourceGroupName $ResourceGroupName -ResourceId $ResouecesToMove.ResourceId -Force

# Delete the temporal resource group.

Remove-AzResourceGroup -Name "TemporalASPFix" -Force