$TemporalPath = "$PSScriptRoot\temporal.xml"
$SubscriptionId = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$TenantId = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$AppServiceToLook = "testwebappdemopester"
$ValidConfig = $(Get-Content -Path "$PSScriptRoot\ConfigFile.json" | convertfrom-json)

##Function definitions
function RunCommand($Dir,$Command,$ResourceGroupName, $WebAppName, $SlotName = $null){
    if ([string]::IsNullOrWhiteSpace($SlotName)){
		$ResourceType = "Microsoft.Web/sites/config"
		$ResourceName = "$WebAppName/publishingcredentials"
	}
	else{
		$ResourceType = "Microsoft.Web/sites/slots/config"
		$ResourceName = "$WebAppName/$SlotName/publishingcredentials"
	}
    $PublishingCredentials = Invoke-AzResourceAction -ResourceGroupName $ResourceGroupName `
                                                     -ResourceType $ResourceType           `
                                                     -ResourceName $ResourceName           `
                                                     -Action list                          `
                                                     -ApiVersion 2015-08-01                `
                                                     -Force
    $KuduApiAuthorisationToken = ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f `
                                   $PublishingCredentials.Properties.PublishingUserName,                                 `
                                   $PublishingCredentials.Properties.PublishingPassword))))

    $KuduApiUrl="https://$WebAppName.scm.azurewebsites.net/api/command"
    $Body = 
      @{
        "command"=$Command;
        "dir"=$Dir
       } 
    $BodyContent=@($Body) | ConvertTo-Json
    Invoke-RestMethod -Uri $KuduApiUrl                                                      `
                      -Headers @{"Authorization"=$KuduApiAuthorisationToken;"If-Match"="*"} `
                      -Method POST -ContentType "application/json" -Body $BodyContent
}

function ConvertConfigIntoHash($Config) {
    $Config.output | Out-File -FilePath $TemporalPath
    $reader = New-Object System.IO.StreamReader($TemporalPath)
    $ConfigForApp = @{}
    if ($null -ne $Reader) {
        while (!$Reader.EndOfStream) {
            $OneLine = $Reader.ReadLine()
            if ($OneLine.Contains("<add key=")) { 
                $Key = $OneLine.Trim().split('="')[2]
                $Value = $OneLine.Trim().split('="')[5]  
                $ConfigForApp += @{$Key = $Value}
            }
        }
    }
    $Reader.Close()
    Remove-Item -Path $TemporalPath
    return $ConfigForApp
}


# Work on every subscription and webapp or just one single subscription and webapp
if ([string]::IsNullOrEmpty($SubscriptionId)){
    $Subs = Get-AzureRmSubscription -TenantId $TenantId
}else{
    $Subs = Get-AzSubscription -SubscriptionId $SubscriptionId -TenantId $TenantId
}

foreach ($Sub in $Subs){
    Write-Output $("Starting in subscription {0}" -f $Sub.Name)
    if(!($Excemptions -match $Sub.Name)){
        Select-AzSubscription -subscriptionname $Sub.Name -tenantid $TenantId
        if($AppServiceToLook){
            Write-Output $("Working in app service {0}" -f $AppServiceToLook)
            $AppService = Get-AzWebApp -Name $AppServiceToLook
            $FileExist = RunCommand -dir "site\wwwroot" -command "dir Web.config" -resourceGroupName $AppService.ResourceGroup -webAppName $AppService.Name
            if ( !($FileExist.Error.contains("File Not Found")) ){
                $Output = RunCommand -dir "site\wwwroot" -command "type Web.config" -resourceGroupName $AppService.ResourceGroup -webAppName $AppService.Name
                # Here Output contains the raw content of web.config, we need to convert into a hash table
                $ValuesFromAppService = ConvertConfigIntoHash -Config $Output
                Describe "Verify there is a configuration entry for $($AppService.Name)" {
                    it "the webapp $($AppService.Name) contains a configuration" {
                        $($ValidConfig | where-object -property name -eq $AppService.Name) | should not be $null    
                    }
                }
                $MatchedConfig = $ValidConfig | Where-Object -Property Name -eq $AppService.Name
                Describe "Verify the keys in $($AppService.Name) have the correct value" {
                    foreach ($item in $MatchedConfig.Values[0].psobject.properties) {
                        It "The key $($item.Name) should exist in appservice $($AppService.Name)" {
                                $ValuesFromAppService.keys -contains $item.Name | should be $true 
                        }
                        It "The key $($item.Name) has the correct value" {
                                $Match = $MatchedConfig.Values[0] | select-object -Property $item.Name
                                $ValuesFromAppService.Item($item.Name) | should be $Match.$($Item.Name) 
                        }
                    }
                }
                Describe "Verify there are no keys in $($AppService.Name) that has no values in the config file" {
                    foreach ($item in $ValuesFromAppService.Keys) {
                        It "Key $($item) found in $($Appservice.Name) is defined in configuration file" {
                            $MatchedConfig.Values[0].psobject.Properties.Name -contains $item | should be $true
                        }
                    }
                }
            }
        }else{
            $AppServices = Get-AzWebApp
            foreach ($AppService in $AppServices){
                Write-Output $("Working in app service {0}" -f $AppService.Name)
                $FileExist = RunCommand -dir "site\wwwroot" -command "dir Web.config" -resourceGroupName $AppService.ResourceGroup -webAppName $AppService.Name
                if ( !($FileExist.Error.contains("File Not Found")) ){
                    $Output = RunCommand -dir "site\wwwroot" -command "type Web.config" -resourceGroupName $AppService.ResourceGroup -webAppName $AppService.Name
                    # Here Output contains the raw content of web.config, we need to convert into a hash table
                    $ValuesFromAppService = ConvertConfigIntoHash -Config $Output
                    Describe "Verify there is a configuration entry for $($AppService.Name)" {
                        it "the webapp $($AppService.Name) contains a configuration" {
                            $($ValidConfig | where-object -property name -eq $AppService.Name) | should not be $null    
                        }
                    }
                    $MatchedConfig = $ValidConfig | Where-Object -Property Name -eq $AppService.Name
                    Describe "Verify the keys in $($AppService.Name) have the correct value" {
                        foreach ($item in $MatchedConfig.Values[0].psobject.properties) {
                            It "The key $($item.Name) should exist in appservice $($AppService.Name)" {
                                    $ValuesFromAppService.keys -contains $item.Name | should be $true 
                            }
                            It "The key $($item.Name) has the correct value" {
                                    $Match = $MatchedConfig.Values[0] | select-object -Property $item.Name
                                    $ValuesFromAppService.Item($item.Name) | should be $Match.$($Item.Name) 
                            }
                        }
                    }
                    Describe "Verify there are no keys in $($AppService.Name) that has no values in the config file" {
                        foreach ($item in $ValuesFromAppService.Keys) {
                            It "Key $($item) found in $($Appservice.Name) is defined in configuration file" {
                                $MatchedConfig.Values[0].psobject.Properties.Name -contains $item | should be $true
                            }
                        }
                    }
                }
            }
        }
    }
}



