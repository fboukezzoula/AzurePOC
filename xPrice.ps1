#.\xPricer.ps1 -Purge no -AzureRmResourceGroup xpricerresourcegroup -AzureRmStorageAccount xpricerstorageaccount -AzureRmBatchAccount xpricerbatchaccount -AzureStorageContainer xpricerstoragecontainer -NbrVM 4 -PoolName xpricerpool

param(
    [Parameter(Mandatory=$false)]
    [String]$Purge = no,
    
    [Parameter(Mandatory=$true)]
    [String]$AzureRmResourceGroup = xpricerresourcegroup,
    
    [Parameter(Mandatory=$true)]
    [String]$AzureRmStorageAccount = xpricerstorageaccount,
    
    [Parameter(Mandatory=$true)]
    [String]$AzureRmBatchAccount = xpricerbatchaccount,
    
    [Parameter(Mandatory=$true)]
    [String]$AzureStorageContainer = xpricerstoragecontainer,    
    
    [Parameter(Mandatory=$true)]
    [int]$NbrVM = 4,
    
    [Parameter(Mandatory=$true)]
    [String]$PoolName = xpricerpool )

# Get-Module PowerShellGet -list | Select-Object Name,Version,Path
# Install-Module AzureRM -Force
# Login-AzureRmAccount
# Warning !!! All ressources will be delete
# Get-AzureRmresourceGroup | Select ResourceGroupName | Remove-AzureRmResourceGroup -Force 

# Setup – First login manually per previous section
# Add-AzureRmAccount

# Now save your context locally (Force will overwrite if there)
# $path = "$env:USERPROFILE\ProfileContext.ctx"
# Save-AzureRmContext -Path $path -Force

# Once that’s done, from then on you can use the Import-AzureRmContext to automate the login.

# Once the above two steps are done, you can simply import
$path = "$env:USERPROFILE\ProfileContext.ctx"
Import-AzureRmContext -Path $path
    
$global:ReturnsxPricerKeys = [System.Collections.ArrayList]@("")
$template_json_file = "c:\template.json"
       
if (($Purge -eq "force")) {    
Remove-AzureRmResourceGroup –Name "$AzureRmResourceGroup" -Force         
}     

# create a resource Group
New-AzureRmResourceGroup –Name "$AzureRmResourceGroup" –Location “West Europe” 

# create storage account
New-AzureRmStorageAccount –ResourceGroup "$AzureRmResourceGroup" –StorageAccountName "$AzureRmStorageAccount" –Location "West Europe" –Type "Standard_LRS" 

# create batch service
New-AzureRmBatchAccount –AccountName "$AzureRmBatchAccount" –Location "Central US" –ResourceGroupName "$AzureRmResourceGroup"

# keys taken from the new batch account created
$Account = Get-AzureRmBatchAccountKeys –AccountName "$AzureRmBatchAccount"
$PrimaryAccountKey = $Account.PrimaryAccountKey
$SecondaryAccountKey = $Account.SecondaryAccountKey 
$global:ReturnsxPricerKeys.Add("$PrimaryAccountKey")
$global:ReturnsxPricerKeys.Add("$SecondaryAccountKey")

# variable for the service batch address URL
$ServiceBatchURL = Get-AzureRmBatchAccount –AccountName "$AzureRmBatchAccount"
$BatchURL = $ServiceBatchURL.TaskTenantUrl

# create pool and retire his url
$context = Get-AzureRmBatchAccountKeys -AccountName "$AzureRmBatchAccount"
$configuration = New-Object -TypeName "Microsoft.Azure.Commands.Batch.Models.PSCloudServiceConfiguration" -ArgumentList @(4,"*")
New-AzureBatchPool -Id "$PoolName" -VirtualMachineSize "Small" -CloudServiceConfiguration $configuration -AutoScaleFormula '$TargetDedicated=' + "$NbrVM" + ';' -BatchContext $context
New-AzureStorageContainer -Name $AzureStorageContainer -Permission Off -Context $context
Write-Host "Pool $PoolName has been created ..."

# write all these inforamtion to a json file
$json = @"
{
   
}
"@

$jobj = ConvertFrom-Json -InputObject $json    
    
$jobj | add-member "AzureRmStorageAccount" "$AzureRmStorageAccount" -MemberType NoteProperty
$jobj | add-member "PrivateKey" "$Key" -MemberType NoteProperty
$jobj | add-member "AzureRmBatchAccount" "$AzureRmBatchAccount" -MemberType NoteProperty
$jobj | add-member "ServiceBatchURL" "$BatchURL" -MemberType NoteProperty
$jobj | add-member "PoolName" "$PoolName" -MemberType NoteProperty
$jobj | add-member "AzureStorageContainer" "$AzureStorageContainer" -MemberType NoteProperty
   
ConvertTo-Json $jobj | Out-File $template_json_file
(Get-Content -path "$template_json_file" -Encoding Unicode) | Set-Content -Encoding "Default" -Path "$template_json_file"
