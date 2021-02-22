param (
    [Parameter(Mandatory=$true)]
    $AzFwName
)

$rg = "internet-outbound-microhack-rg"
$location = (Get-AzResourceGroup -Name $rg).Location
$optimizePriority = 1158
$allowPriority = 1159

$wvdSessionHostPoolSubnet = "10.59.1.0/24"

Write-Host "Retrieving O365 endpoints from web service..."

$endpoints = invoke-restmethod -Uri ("https://endpoints.office.com/endpoints/WorldWide?NoIPv6=true&clientrequestid=" + ([GUID]::NewGuid()).Guid) 
$endpoints = $endpoints | ? {$_.category -eq "Optimize" -or $_.category -eq "Allow"}

Write-Host "Done!"

$optimizeNetworkRules = @()
$allowNetworkRules = @()
$optimizeApplicationRules = @()
$allowApplicationRules = @()


foreach ($endpoint in $endpoints) {
    if (-not ($endpoint.urls -eq $null)) {
        
        Write-Host "Creating application rule for" $endpoint.serviceAreaDisplayName
        
        $uniqueName = $endpoint.id.ToString() + "_O365_" + $endpoint.category + "_" + $endpoint.serviceAreaDisplayName.Replace(" ", "_")
        
        $protocols = @("https:443","http:80") 
        
        if ($endpoint.category -eq "Optimize") {
            $optimizeApplicationRules += New-AzFirewallApplicationRule -Name "rule_$uniqueName" -SourceAddress $wvdSessionHostPoolSubnet -TargetFqdn $endpoint.urls -Protocol $protocols 
        }
        
        if ($endpoint.category -eq "Allow") {
            $allowApplicationRules += New-AzFirewallApplicationRule -Name "rule_$uniqueName" -SourceAddress $wvdSessionHostPoolSubnet -TargetFqdn $endpoint.urls -Protocol $protocols 
        } 
    }
    
    if (-not($endpoint.ips -eq $null)) {
        Write-Host "Creating network rule for" $endpoint.serviceAreaDisplayName
        $ips = $endpoint | select -Unique -ExpandProperty ips
        $ports = @()
        $protocols = @()
        if (-not ($endpoint.tcpPorts -eq $null)) {
            $protocols += "TCP"
            $ports = $endpoint.tcpPorts.Split(',')
        }
        if (-not ($endpoint.udpPorts -eq $null)) {
            $protocols += "UDP"
            $ports = $endpoint.udpPorts.Split(',')
        }
        try {
            $ipGroup = Get-AzIpGroup -Name "ipgroup_$uniqueName" -ResourceGroupName $rg -ErrorAction Stop
        }
        catch {
            $ipGroup = New-AzIpGroup -Name "ipgroup_$uniqueName" -ResourceGroupName $rg  -Location $location -IpAddress $ips
        }
    
        if ($endpoint.category -eq "Optimize") {
            $optimizeNetworkRules += New-AzFirewallNetworkRule -Name "rule_$uniqueName" -SourceAddress $wvdSessionHostPoolSubnet -DestinationIpGroup $ipGroup.Id -DestinationPort $ports -Protocol TCP
        }
        
        if ($endpoint.category -eq "Allow") {
            $allowNetworkRules += New-AzFirewallNetworkRule -Name "rule_$uniqueName" -SourceAddress $wvdSessionHostPoolSubnet -DestinationIpGroup $ipGroup.Id -DestinationPort $ports -Protocol TCP
        } 
    }
}

Write-Host "Creating firewall config..."

$optimizeApplicationRuleCollection = New-AzFirewallApplicationRuleCollection -Name O365-Optimize -Priority $optimizePriority -ActionType Allow -Rule $optimizeApplicationRules
$allowApplicationRuleCollection = New-AzFirewallApplicationRuleCollection -Name O365-Allow -Priority $allowPriority -ActionType Allow -Rule $allowApplicationRules
$optimizeNetworkRuleCollection = New-AzFirewallNetworkRuleCollection -Name O365-Optimize -Priority $optimizePriority -ActionType Allow -Rule $optimizeNetworkRules
$allowNetworkRuleCollection = New-AzFirewallNetworkRuleCollection -Name O365-Allow -Priority $allowPriority -ActionType Allow -Rule $allowNetworkRules

Write-Host "Setting firewall config..."
$azfw = Get-AzFirewall -Name $azFwName -ResourceGroupName $rg
$azfw.ApplicationRuleCollections.Add($optimizeApplicationRuleCollection)
$azfw.ApplicationRuleCollections.Add($allowApplicationRuleCollection)
$azfw.NetworkRuleCollections.Add($optimizeNetworkRuleCollection)
$azfw.NetworkRuleCollections.Add($allowNetworkRuleCollection)
$azfw = Set-AzFirewall -AzureFirewall $azfw
Write-Host "Done!"
