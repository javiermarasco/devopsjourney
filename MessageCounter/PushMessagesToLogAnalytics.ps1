$Subscription = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"   # Subscription Id where the resources are deployed.
$TenantId = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"       # Tenant where you have your subscription

$client_id = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'      # Application ID of the SPN created to run the script
$client_secret = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'  # Secret of the SPN created


$WorkspaceId = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"    # Workspace ID of the Log Analytics
$SharedKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"    # Replace with your Primary Key from your Log Analytics

$LogType = "ServiceBusMessageCount" # Specify the name of the table record type that you'll be creating in your Log Analytics

$ResourceGroupName = "servicebuscounts"
$ServiceBusName = "countertester"

# Creates the header to send requests to Azure
function GetAzureAuthHeader {
    $token = Invoke-RestMethod `
             -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token?api-version=1.0" `
             -Method Post `
             -Body @{
                        "grant_type" = "client_credentials";
                        "resource" = "https://management.core.windows.net/";
                        "client_id" = $client_id;
                        "client_secret" = $client_secret;
                    };
    $header = @{
        'Authorization' = $("Bearer " + $token.access_token);
    };
    write-host "Logging to Azure finished.";
    return $header;
}
# Builds signature to post to LogAnalytics
Function BuildSignature ($WorkspaceId, $sharedKey, $date, $contentLength, $method, $contentType, $resource){
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $WorkspaceId,$encodedHash
    return $authorization
}
# Posts custom data to LogAnalytics
Function PostLogAnalyticsData($WorkspaceId, $sharedKey, $body, $logType){
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = BuildSignature `
        -WorkspaceId $WorkspaceId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
    $TimeStampField = "TimeGenerated"
    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }
    $response = Invoke-RestMethod -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body
    return $response.StatusCode
}
$Header = GetAzureAuthHeader
$ServiceBusTopicQueryURL = "https://management.azure.com//subscriptions/$Subscription/resourceGroups/$ResourceGroupName/providers/Microsoft.ServiceBus/namespaces/$ServiceBusName/topics?api-version=2017-04-01"
$ServiceBusTopics = $(Invoke-RestMethod -Uri $ServiceBusTopicQueryURL -Headers $Header -Method Get  -ErrorAction Stop)
foreach ($Topic in $ServiceBusTopics.value.name) {
    $ServiceBusSubscriptionQueryURL = "https://management.azure.com//subscriptions/$Subscription/resourceGroups/$ResourceGroupName/providers/Microsoft.ServiceBus/namespaces/$ServiceBusName/topics/$Topic/subscriptions?api-version=2017-04-01"
    $ServiceBusSubscriptions = $(Invoke-RestMethod -Uri $ServiceBusSubscriptionQueryURL -Headers $Header -Method Get  -ErrorAction Stop)
    foreach ($ServiceBusSubscription in $ServiceBusSubscriptions.value) {
        $jsonActive = @{
            "ServiceBusTopicName" = $Topic
            "ServiceBusSubscriptionName" = $ServiceBusSubscription.name
            "ServiceBusSubscriptionActiveMessageCount" = $ServiceBusSubscription.properties.countDetails.activeMessageCount
        }
        $json = $jsonActive | ConvertTo-Json
        # Submit the data to the API endpoint for active messages
        PostLogAnalyticsData -WorkspaceId $WorkspaceId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
        $jsonDLQ = @{
            "ServiceBusTopicName" = $Topic
            "ServiceBusSubscriptionName" = $ServiceBusSubscription.name
            "ServiceBusSubscriptionDLQMessageCount" = $ServiceBusSubscription.properties.countDetails.deadLetterMessageCount
        }
        $json = $jsonDLQ | ConvertTo-Json
        # Submit the data to the API endpoint for dead letter queue (DLQ) messages
        PostLogAnalyticsData -WorkspaceId $WorkspaceId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
    }
}