param (
    [Parameter(Mandatory=$true)]
    $AzFwName
)

$rg = "internet-outbound-microhack-rg"
$dbricksVnet = "10.60.0.0/16"

$dbfsRootBlob = (Get-AzStorageAccount | ? {$_.ResourceGroupName -eq "internet-outbound-microhack-dbricks-managed-rg"}).StorageAccountName


$appRulesUrls = @( `
@("$dbfsRootBlob.blob.core.windows.net",'https','dbfsroot_blob'), `
@('tunnel.westeurope.azuredatabricks.net','https','scc_relay_1'), ` 	
@('tunnel.westeuropec2.azuredatabricks.net','https','scc_relay_2'), ` 	
@('dbartifactsprodwesteu.blob.core.windows.net','https','artifact_blob_1'), `
@('arprodwesteua1.blob.core.windows.net','https','artifact_blob_2'), ` 	
@('arprodwesteua2.blob.core.windows.net','https','artifact_blob_3'), ` 	
@('arprodwesteua3.blob.core.windows.net','https','artifact_blob_4'), `
@('arprodwesteua4.blob.core.windows.net','https','artifact_blob_5'), `
@('arprodwesteua5.blob.core.windows.net','https','artifact_blob_6'), `
@('arprodwesteua6.blob.core.windows.net','https','artifact_blob_7'), `
@('dbartifactsprodnortheu.blob.core.windows.net','https','artifact_blob_8'), `
@('dblogprodwesteurope.blob.core.windows.net','https','log_blob'), `
@('prod-westeurope-observabilityeventhubs.servicebus.windows.net','https:9093','eventhub_1'), `
@('prod-westeuc2-observabilityeventhubs.servicebus.windows.net','https:9093','eventhub_2'))

$appRules = @()

$index = 1
foreach ($url in $appRulesUrls) {
    $fqdn = $url[0]
    $port = $url[1]
    $ruleName = $url[2]

    $appRules += new-AzFirewallApplicationRule -Name $ruleName -SourceAddress $dbricksVnet -TargetFqdn $fqdn -Protocol $port -Description "Allow access to $ruleName"
    $index += 1
    Write-Host "Created application rule $ruleName for FQDN: $fqdn and port: $port"
         
}
$dbricksApplicationRuleCollection = New-AzFirewallApplicationRuleCollection -Name Dbricks-ApplicationRules -Priority 1257 -ActionType Allow -Rule $appRules

$netRules = @()
$netRules += new-AzFirewallNetworkRule -Name "webapp_1" -SourceAddress $dbricksVnet -DestinationAddress "52.232.19.246/32" -DestinationPort 443 -Protocol TCP -Description "Allow access to Databricks WebApp"
$netRules += new-AzFirewallNetworkRule -Name "webapp_2" -SourceAddress $dbricksVnet -DestinationAddress "40.74.30.80/32" -DestinationPort 443 -Protocol TCP -Description "Allow access to Databricks WebApp"
Write-Host "Created network rule(s) for Databricks WebApp"
$netRules += new-AzFirewallNetworkRule -Name "metastore_1" -SourceAddress $dbricksVnet -DestinationFqdn "consolidated-westeurope-prod-metastore.mysql.database.azure.com" -DestinationPort 3306 -Protocol TCP -Description "Allow access to Databricks metastore"
$netRules += new-AzFirewallNetworkRule -Name "metastore_2" -SourceAddress $dbricksVnet -DestinationFqdn "consolidated-westeurope-prod-metastore-addl-1.mysql.database.azure.com" -DestinationPort 3306 -Protocol TCP -Description "Allow access to Databricks metastore"
$netRules += new-AzFirewallNetworkRule -Name "metastore_3" -SourceAddress $dbricksVnet -DestinationFqdn "consolidated-westeuropec2-prod-metastore-0.mysql.database.azure.com" -DestinationPort 3306 -Protocol TCP -Description "Allow access to Databricks metastore"
Write-Host "Created network rule(s) for Databricks Metastore"

$dbricksNetworkRuleCollection = New-AzFirewallNetworkRuleCollection -Name Dbricks-NetworkRules -Priority 1257 -ActionType Allow -Rule $netRules

Write-Host "Adding rules to firewall config..."
$azfw = Get-AzFirewall -Name $azFwName -ResourceGroupName $rg
$azfw.ApplicationRuleCollections.Add($dbricksApplicationRuleCollection)
$azfw.NetworkRuleCollections.Add($dbricksNetworkRuleCollection)
Write-Host "Updating firewall..."
$azfw = Set-AzFirewall -AzureFirewall $azfw
Write-Host "Done!"
