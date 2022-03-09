# Handling internet access in Azure, for effective WVD and Azure PaaS designs - MicroHack

### [Scenario](#scenario)
### [Prerequistes](#prerequisites)

### [Challenge 1: Forced tunneling](#challenge-1-forced-tunneling-1)

### [Challenge 2: Route internet traffic through Azure Firewall](#challenge-2-route-internet-traffic-through-azure-firewall-1)

### [Challenge 3: Add a proxy solution](#challenge-3-add-a-proxy-solution-1)

### [Challenge 4: Deploy Azure Databricks](#challenge-4-deploy-azure-databricks-1)

# Scenario
Contoso Inc., a financial services company, has recently started a datacenter migration project aimed at moving several LOB applications and a VDI farm to Azure. In its corporate network, Contoso enforces a strict security policy for internet access. The security team requested that the same policy be applied in the cloud. To address this requirement, the network team configured Azure VNets to route back to the on-prem datacenter all internet-bound connections (aka "[forced tunneling](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-forced-tunneling-rm)").  Both the security team and Contoso's CTO endorsed the solution. Forced tunneling allows managing internet traffic in the cloud in the very same way as in the corporate network. Also, it leverages the significant investments made by Contoso over the last few years in on-premises network security equipment, such as firewalls, proxies, IDS/IPS.

Forced tunneling allowed Contoso to migrate the first, simple IaaS workloads (lift&shift). But its limitations became clear as soon as Contoso deployed more advanced Azure services:

- Users reported poor performance when using Windows Virtual Desktop, which was identified as the most cost-effective solution to move VDI workloads to Azure;
- WVD users generated a high volume of traffic related to internet browsing, which drove hybrid connectivity costs up;
- Many VNet-injected PaaS services (such as [Databricks](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/on-prem-network) and [HDInsight](https://docs.microsoft.com/en-us/azure/hdinsight/control-network-traffic#forced-tunneling-to-on-premises) that Contoso' s data scientists plan to deploy) have internet access requirements that are difficult to address with forced tunneling.  

This MicroHack walks through the implementation of a secure internet edge in the cloud, based on Azure Firewall, that overcomes the limitations of forced tunneling and enables Contoso to deploy the advanced PaaS services required by the business, while complying with corporate security policies.
# Prerequisites
## Overview

In order to use the MicroHack time most effectively, the following tasks should be completed prior to starting the session.
At the end of this section your base lab build looks as follows:

![image](images/initial-setup.png)

In summary:

- Contoso's on-prem datacenter is  simulated by an Azure Virtual Network ("onprem-vnet"). It contains a Linux VM that (1) terminates a site-2-site VPN connection to Contoso's Azure network and (2) simulates Contoso's on-prem secure internet edge (proxy based on Squid). Please note that  Linux system administration skills and knowledge of IPTables/Squid are *not* required to complete this MicroHack. 
- Contoso's Azure virtual datacenter is a hub&spoke network. The hub VNet ("hub-vnet") contains a Virtual Network Gateway that terminates the site-2-site VPN connection to Contoso's on-prem datacenter. The spoke VNet ("wvd-spoke-vnet") contains a Win10 workstation that  *simulate*s a WVD workstation (it is a standalone VM, not a WVD session host, to reduce complexity. But all the network-related configurations that will be discussed apply with no changes to a real WVD session host).
- Azure Bastion is deployed in the "onprem-vnet"  and in the "wvd-spoke-vnet "to enable easy remote desktop access to virtual machines.
- All of the above is deployed within a single resource group called *internet-outbound-microhack-rg*.


## Task 1 : Deploy Templates

We are going to use a predefined Terraform template to deploy the base environment. It will be deployed in to *your* Azure subscription, with resources running in the specified Azure region.

To start the Terraform deployment, follow the steps listed below:

- Login to Azure cloud shell [https://shell.azure.com/](https://shell.azure.com/)
- Ensure that you are operating within the correct subscription via:

`az account show`

- Clone the following GitHub repository 

`git clone https://github.com/fguerri/internet-outbound-microhack`

- Go to the new folder "internet-outbound-microhack/templates" and initialize the terraform modules and download the azurerm resource provider

`cd internet-outbound-microhack/templates`

`terraform init`

- Now run apply to start the deployment 

`terraform apply`

- Choose a suitable password to be used for your Virtual Machines administrator account (username: adminuser)

- Choose you region for deployment (location). E.g. eastus, westeurope, etc

  > **WARNING IN DEPLOYMENT REGION !! :** If you plan to go through Challenge 4, you **should deploy** your Microhack environment in **Azure West Europe**. Some tasks in challenge 4 require configuration steps that are region-dependent. Scripts to automate those steps are provided for West Europe only. It is possible to complete Challenge 4 when the Microhack enviroment is deployed in different regions, but this will require more manual configuration steps (instructions are provided).  

- When prompted, confirm with a **yes** to start the deployment

- Wait for the deployment to complete. This will take around 30 minutes (the VPN gateway takes a while).

## Task 2 : Explore and verify the deployed resources

- Verify you can access via Azure Bastion both the Win10 VM in the "wvd-spoke-vnet" and the on-prem Linux box (Username: "adminuser"; Password: as per the above step).

- Verify that your VNet Peering and Site-to-site VPN are functioning as expected: From the "wvd-workstation" VM, access the on-prem Linux box via SSH (IP address: 10.57.2.4).

  > Please note that "ssh" is available in the Windows 10 Command Prompt. You can also install Putty or your favorite SSH client.

## :checkered_flag: Results

- You have deployed a basic Azure and On-Premises environment using a Terraform template
- You have become familiar with the components you have deployed in your subscription
- You are now able to login to all VMs using your specified credentials
- End-to-end network connectivity has been verified from On-Premises to Azure

Now that we have the base lab deployed, we can progress to the MicroHack challenges!
# Challenge 1: Forced tunneling

In this challenge, you will configure forced tunneling in Contoso's Azure VNets, as initially suggested by the network team.  

## Task 1: Configure default route in wvd-spoke
Your MicroHack environment has been deployed with a default routing configuration whereby Azure VMs have direct access to the internet. Log onto the wvd-workstation, open Microsoft Edge and verify that you can browse the internet without restrictions. Before modifying the existing configuration, point your browser to https://ipinfo.io and take note of the public IP address it returns. Confirm that it is the public IP address assigned to your VM. In the Azure portal, search "wvd-workstation" and find the public IP address in the "Overview" section:

![image](images/wvd-workstation-pip.png)

In the Azure portal, find the Route Table "wvd-spoke-rt" associated to the wvd-workstation's subnet and add a default route to send all internet-bound traffic to on-prem, via the site-2-site IPSec tunnel:

![image](images/default-route.png)

In Azure Cloud Shell, configure the VPN Gateway with a default route to send all internet-bound traffic to on-prem:

`$lgw = Get-AzLocalNetworkGateway -Name onprem-lng -ResourceGroupName internet-outbound-microhack-rg`

`$gw = Get-AzVirtualNetworkGateway -Name hub-vpngw -ResourceGroupName internet-outbound-microhack-rg`

`Set-AzVirtualNetworkGatewayDefaultSite -VirtualNetworkGateway $gw -GatewayDefaultSite $lgw`

> Please note that setting the VPN gateway default site is only required for statically routed tunnels (i.e. when BGP is not used). Similarly, no default site setting is needed when using Expressroute instead of site-to-site VPN. More details are available [here](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-forced-tunneling-rm#configure-forced-tunneling-1).

Verify that internet access from the wvd-workstation is now controlled by Contoso's on-prem proxy. Browse again to https://ipinfo.io. The error message that you see is due to the TLS inspection performed by the proxy. 

![image](images/invalid-cert.png)

In order to access the internet via Contoso's on-prem proxy, you must configure the wvd-workstation to trust the certificates issued by the proxy, which we will do in the next task.

## Task 2: Access the internet via on-prem proxy

The on-prem proxy performs TLS inspection by terminating on itself the TLS connection initiated by your browser and setting up a new one between itself and the server. As the proxy does not have access to the server's private key, it dynamically generates a new certificate for the server's FQDN. The certificate is signed by Contoso's enterprise CA, which your browser does not currently trust.

![image](images/cert-path.png)

As a Contoso employee, you are willing to trust Contoso's Enterprise CA, which you can do by installing it in your certificate store. 

- Select the "Contoso Enterprise CA" certificate as shown in the previous figure
- Click on "View certificate"
- Click on "Details"
- Click on "Copy to file...", accept all defaults suggested by the wizard and save the certificate on your desktop

![image](images/download-cert.png)

- Double-click on the certificate file on your desktop and use the wizard to install it in the "Trusted Root Certification Authorities" store

![image](images/install-cert.png)

> You may wonder if installing the proxy's self-signed certificate is a security best practice. While in general you should never install  certificates from unknown third parties in the "Trusted Root Certification Authorities" store, in this scenario you are installing on a Contoso workstation a certificate generated by Contoso's own certification authority. Many organizations use root certificate authorities to generate certificates that are meant to be trusted only internally. 

> In real-world scenarios, certificates can be automatically distributed to workstations using configuration management tools (for example, certificates can be distribute to domain-joined computers by means of Windows Server AD GPOs). 

- Close Microsoft Edge, launch it again and verify that you can now access https://ipinfo.io
- Verify that the public IP you're using to access the internet is now the proxy's public IP

![image](images/confirm-public-ip.png)

Now that your browser trusts the certificates generated by the proxy, you can browse the internet, subject to Contoso's security policy. 

- Browse to https://docs.microsoft.com and confirm that you can access the site
- Confirm that you can access O365 applications. For example, browse to https://outlook.office365.com and access your mailbox (if you have one)
- Browse to any other sites such as https://ebay.com or https://www.wired.com and confirm that your connections are blocked by the proxy 

## :checkered_flag: Results

You have now a forced tunnel configuration in place. 

![image](images/forced-tunnel.png)

- All connections initiated by the wvd-workstation are routed to Contoso's on-prem datacenter
- HTTP/S connections are transparently intercepted by the proxy and allowed/denied based on the configured security policy. The proxy bumps TLS connections, which allows further inspection (IDS/IPS, anti-virus, etc)
- Any other connection initiated by the wvd-workstation is routed to Contoso's on-prem firewall and dropped 

# Challenge 2: Route internet traffic through Azure Firewall

In this challenge you will explore how Contoso can address the performance problem reported by WVD users. You will build a secure edge in Azure, thus removing the need to route all internet-bound connections to Contoso's on-prem datacenter (red line). Routing WVD traffic directly to the internet via Azure Firewall reduces latency and improves user experience (green line).

![image](images/forced-vs-direct.png)

## Task 1: Deploy Azure Firewall

In the Azure Portal, deploy a new Azure Firewall instance in the hub-vnet. A subnet named "AzureFirewallSubnet" has been already created for you. 

![image](images/firewall.png)

> Please note that the "Forced tunneling" switch must be disabled. The switch allows forwarding internet traffic to custom next hops (including gateways connected to remote networks) after it has been inspected by Azure Firewall. In this scenario, you are using Azure Firewall as your secure internet edge and want your internet traffic to egress to the internet directly, after being inspected by Azure Firewall.

Your Azure Firewall instance will take about 10 minutes to deploy. When the deployment completes, go to the new firewall's overview tile a take note of its *private* IP address. This IP address will become the default gateway for Contoso's Azure VNets. 

## Task 2: Configure a default route via azure Firewall

In the Azure portal, go to your Azure Firewall instance's "Overview" and take note of its private IP address:

![image](images/firewall-overview.png)

Go to the Route Table "wvd-spoke-rt" and modify the next hop of the default route that you defined in the previous challenge. To do so, click on “Routes” on the menu on the left, find the custom default route that you defined in the previous challenge and click on it. Replace the next hop "Virtual Network Gateway" with the private IP of your Azure firewall instance. 

![image](images/default-via-azfw.png)

Remove the default route configuration from the VPN gateway (configured in Challenge 1):

`$gw= Get-AzVirtualNetworkGateway -Name hub-vpngw -ResourceGroupName internet-outbound-microhack-rg`

`Remove-AzVirtualNetworkGatewayDefaultSite -VirtualNetworkGateway $gw`

Verify that you no longer have connectivity to the internet from the wvd-workstation. Connections are now being routed to Azure Firewall, which is running with the default "deny all" policy.

## Task 3: Implement Contoso's security policy with Azure Firewall rules

Configure Azure Firewall to implement the same internet access policy as Contoso's on-premises proxy:

- Access to "docs.microsoft.com" is allowed
- Access to "ipinfo.io" is allowed
- Access to any other sites is denied

In the Azure Portal, create a new application rule collection for Azure Firewall as shown in the screenshot below.

![image](images/manual-azfw-policy.png)

Confirm that you can now access https://ipinfo.io and https://docs.microsoft.com. Verify that your public IP address is now the public IP address of your Azure Firewall.

![image](images/azfw-public-ip.png)

## Task 4: Enable access to WVD endpoints via Azure Firewall

In this task you will address the performance issues reported by Contoso's WVD users, by allowing direct access to WVD endpoints via Azure Firewall. 

WVD session hosts connect to a list of well-known endpoints, documented [here](https://docs.microsoft.com/en-us/azure/virtual-desktop/safe-url-list#virtual-machines). Each WVD endpoint has an associated Azure Service Tag. 

![image](images/wvd-endpoints.png)

Azure Firewall supports service tags, which would make it easy to configure rules to allow access to WVD required URLs.  However, Azure Firewall rules allowing connections to "Azure Cloud" and "Internet" are too permissive and not compatible with Contoso's security requirements.

You have negotiated with the security team a solution that strikes an acceptable trade-off between security and WVD performance:

- Only the "Windows Virtual Desktop" service tag, which corresponds to a small set of Microsoft-controlled endpoints, will be used in the firewall configuration
- For the other required URLs, application rules matching only the specific URLs will be used.

To implement this policy, go to the "scripts/" directory and execute the wvd-firewall-rules.ps1 script. 

  `cd internet-outbound-microhack/scripts`

  `./wvd-firewall-rules.ps1 -AzFwName <your Azure Firewall name>`

When done, go to your Azure Firewall configuration in the portal and verify that you have two rule collections (one network rule collection, one application rule collection) that allow access to the endpoints listed in the previous figure.

## :checkered_flag: Results

You have implemented a secure internet edge based on Azure Firewall, which allows Contoso to control internet access for the wvd-workstation without routing traffic to the on-prem proxy. This approach reduces latency for connections between the wvd-workstation and the WVD control plane endpoints and helps improve the WVD user experience. It also allows Contoso to provide WVD users with access to external, trusted web sites directly from Azure.

# Challenge 3: Add a proxy solution

Contoso's security team recognized that the solution implemented in the previous challenge works well for server-generated traffic, such as connections between WVD session hosts and WVD endpoints. Azure Firewall, with its IP- and FQDN-based filtering capabilities,  provides a cost-effective solution to secure access to known/trusted endpoints. However, with WVD being rolled out, Contoso raised concerns about its applicability to securing traffic generated by users browsing the internet from their WVD workstations:    

- Users tend to access broad sets of URLs, which are best specified by category (news, e-commerce, gambling, ...) instead of black/whitelists of known FQDNs
- The security team insists on applying TLS inspection at least to connections to low-trust domains, as Contoso's on-prem proxy currently does
- The security team considers the existing on-prem proxy a fundamental security control, because of its logging, inspection and authentication capabilities. At the same time, they have no budget to deploy a functionally equivalent proxy solution in Azure.
- The security team is also reluctant to approve direct access via Azure Firewall to the [broad set of URLs required by Office365](https://docs.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide). The topic is highly controversial because routing O365 traffic back to on-prem would drive cost for ER and/or VPN connectivity up

The following solution has been identified as the optimal trade-off between the conflicting requirements listed above:

- Server VMs will access the internet directly via Azure Firewall (i.e. the configuration you created in Challenge 2)
- WVD workstations will use a  selective proxying policy whereby trusted destinations (such as Azure PaaS services and a subset of O365 URLs) will be reached directly via Azure Firewall, while general internet traffic is sent to Contoso's on-premises security appliances.

The following tasks will walk through the configuration of WVD workstations.

> A new Azure Firewall SKU has been [announced](https://azure.microsoft.com/en-us/blog/azure-firewall-premium-now-in-preview-2/) (in public preview) that addresses most of Contoso's requirements listed above. Stay tuned for updates to this Microhack that will cover the newly introduced capabilities around TLS Inspection, signature-based IDPS, Web categories and URL filtering. However, the configuration that you will build in this task remains relevant in all those scenarios where sending traffic to an explicit proxy allow meeting advanced requirements (for example, authenticated access to sensitive sites). 

## Task 1: Configure an explicit proxy on wvd-workstation

As the wvd-workstation runs in a subnet whose default gateway is now Azure Firewall (Challenge 2), you cannot rely on transparent proxy interception as you did in Challenge 1. An explicit proxy configuration is now required. Moreover, you need to specify which destinations should be reached directly via Azure Firewall and which ones should be reached via Contoso's on-prem proxy. You can do so by means of a "Proxy Automatic Configuration (PAC)" file. In the Microhack environment, some PAC files are available at http://10.57.2.4:8080. To configure Microsoft Edge to use a PAC:

- verify that a PAC file is available by browsing to http://10.57.2.4:8080/proxypac-3-1.pac. Note that, on line 7, the script allows direct access (i.e. not proxied) to "ipinfo.io"
- go to "Settings" ==> "System" ==> "Open System Proxy Settings"
- enter "http://10.57.2.4:8080/proxypac-3-1.pac" as the script address
- click "Save"

![image](images/proxy-pac-setup.png)

- Open a new tab and browse to https://ipinfo.io to see the public IP address you're using to access the internet. Verify that it is  your Azure Firewall's public IP. This confirms that you are reaching https://ipinfo.io directly .

![image](images/azfw-public-ip.png)

- Open a new tab and browse to https://ipconfig.io/json. Verify that it is the public IP assigned to the onprem-proxy-vm. This confirms that you are reaching https://ipconfig.io/json via Contoso's on-prem proxy.

![image](images/on-prem-public-ip.png)

The effect of your current routing and proxying policy is shown in the figure below.

![image](images/internet-access-via-proxy.png)

## Task 2: Optimize O365 connectivity

The selective proxying configuration defined in the previous task can be used to optimize access to Office365, according to the connectivity principles documented [here](https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-network-connectivity-principles?view=o365-worldwide#new-office-365-endpoint-categories). In a nutshell, the endpoints and URLs that must be reachable from a workstation to successfully consume O365 applications are divided into three categories:

- **Optimize** endpoints are required for connectivity to  every Office 365 service and represent over 75% of Office 365 bandwidth, connections, and volume of data. These endpoints represent Office 365  scenarios that are the most sensitive to network performance, latency,  and availability. All endpoints are hosted in Microsoft datacenters. The rate of change to the endpoints in this category is expected to be much lower than for the endpoints in the other two categories.
- **Allow** endpoints are required for connectivity to  specific Office 365 services and features, but are not as sensitive to  network performance and latency as those in the *Optimize*  category. The overall network footprint of these endpoints from the  standpoint of bandwidth and connection count is also smaller. These  endpoints are dedicated to Office 365 and are hosted in Microsoft  datacenters.
- **Default** endpoints represent Office 365 services and  dependencies that do not require any optimization, and can be treated by customer networks as normal Internet bound traffic. Some endpoints in  this category may not be hosted in Microsoft datacenters.

As the "Optimize" and "Allow" endpoints are hosted in Microsoft datacenters, Contoso's security team has accepted to allow direct access to them via Azure Firewall. They requested that the on-prem proxy is used only for traffic to the "Default" endpoints. 

To implement this policy, you are going to need:

- a PAC file to bypass the proxy for connections to "Optimize" and "Allow" endpoints
- Azure Firewall rules to allow connections to "Optimize" and "Allow" endpoint

Contoso's on-prem proxy already allows access to "Default" endpoints because it is currently used to consume those endpoints from the corporate network. 

An [Office 365 IP Address and URL web service](https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-ip-web-service?view=o365-worldwide) allows downloading an up-to-date list of all endpoints (URLs, IP addresses, category, etc). Therefore, both the proxy PAC file and the firewall rules can be automatically generated (and refreshed on a regular basis). In the MicroHack environment, the PAC file has been already generated and can be downloaded from http://10.57.2.4:8080/O365-optimize.pac. In order to use it, update the PAC settings in Microsoft Edge:

![image](images/o365-proxy-pac.png)

Now try and access your O365 mailbox at https://outlook.office365.com. You will get an access denied message. This is expected: The PAC file causes some connections to go directly to Azure Firewall, which is not yet configured with the proper rules.

The Azure Firewall rules can be generated automatically, by consuming the endpints web service. A Powershell script is provided to do so:
- go to the "internet-outboud-microhack/scripts/" directory

  `cd internet-outbound-microhack/scripts`

- run the Powershell script "o365-firewall-rules.ps1"

  `./o365-firewall-rules.ps1 -AzFwName <your Azure Firewall name>`

- When the script completes, go to the Azure portal and verify that network and application rule collections have been created for "Optimize" and "Allow" endpoints 

- Verify that you can successfully log into your O365 mailbox at https://outlook.office365.com.
## :checkered_flag: Results

You have built a network configuration that does not rely on forced tunneling and allows Contoso to leverage Azure Firewall to access Azure PaaS services and O365 applications with minimal latency. At the same time, you addressed the security team's requirement to use an existing on-prem proxy solution to secure generic internet access from WVD workstations.
![image](images/o365-traffic.png)

# Challenge 4: Deploy Azure Databricks 

In this challenge, you will deploy Azure Databricks in Contoso's network. 

> This challenge requires familiarity with Azure Databricks. Detailed instructions are provided only for network-related configurations.

The default deployment of Azure Databricks is a fully managed service on Azure: all data plane resources, including a VNet that all clusters will be associated with, are deployed to a locked resource group. This turned out to be an adoption blocker for Contoso. On the one hand, data scientists expect Databricks clusters to be able to access resources in the corporate network; On the other hand, the security team does not authorize any peerings between Contoso's hub VNet and spoke VNets for which Contoso does not control routing and security policies.    

To address these conflicting requirements, you will deploy a VNet-injected Databricks workspace. [VNet injection](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject) allows customers to run Databricks clusters in their own VNets, thus retaining control on how traffic to/from clusters is routed (up to a certain extent: Some UDRs and NSG rules must exist for the service to work properly, as you shall see in the following tasks). You will take advantage of the flexibility afforded by VNet injection to route Databricks cluster traffic through the Azure Firewall deployed in Challenge 2. 

## Task 1: Deploy Databricks in a customer-managed VNet

In the MicroHack environment, a spoke VNet named "dbricks-spoke-vnet" has been provisioned to host VNet-injected Databricks clusters. In the Azure portal, browse to the "internet-outbound-microhack-rg" resource group, locate the VNet resource named "dbricks-spoke-vnet" and verify that it has been configured as follows : 

-  two subnets ("dbricks-public-subnet" and "dbricks-private-subnet") have been defined and delegated to "Microsoft.Databricks/workspaces"
- each subnet is associated to a network security group (dbricks-public-nsg, dbricks-private-nsg)

More details about network prerequisites for VNet-injected Databricks clusters are available in the [public documentation](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject#--virtual-network-requirements).

The "dbricks-spoke-vnet" has been peered with the hub VNet. A custom route table has been associated with Databricks' subnets, with a default route that prevents connections to the internet ("next hope type" = "none"). You will modify this route in the next task.

![image](images/dbricks-spoke-vnet.png)

To deploy a VNet-injected Azure Databricks workspace in the "dbricks-spoke-vnet" VNet: 

- go to the "templates-dbricks" directory and deploy the Terraform templates:

  `cd internet-outbound-microhack/templates-dbricks`

  `terraform init`

  `terraform apply`

- When prompted to provide a value for the variable "secure_cluster_connectivity", enter "true" (more on [Databricks Secure Cluster Connectivity](https://docs.microsoft.com/en-us/azure/databricks/security/secure-cluster-connectivity) in the next task)

While the Databricks workspace provisioning completes, move to the next task.

## Task 2: Review Databricks network architecture and connectivity requirements 

The network architecture of a VNet-injected Databricks workspace is shown in the figure below.

![image](images/dbricks-vnet-injection.png)

Databricks cluster nodes are Azure VMs with two NICs, running in a customer-managed VNet. The NICs attached to the "private" subnet are used for intra-cluster connections (driver node <==> worker nodes) and for connections to endpoints within the corporate network. The NICs attached to the "public" subnet are used for connections to the multi-tenant Databricks control plane and for access to external, custom data sources. Each public NICs is configured with a public IP address. These addresses are the cluster's public IPs that the multi-tenant control plane contacts to manage the cluster and submit jobs.

The control plane is deployed in a Microsoft-managed subscription and controls multiple workspaces belonging to different customers. It is comprised of several elements (Web App, Cluster Management, Event Hub, Metastore, Artifact store). Only the "Cluster management" element initiates connections to the cluster's public IPs . Cluster nodes initiate connections to all the other control plane elements. 

Each workspace is also associated to a "Root DBFS" storage account, deployed in the customer's subscription. 

In order to allow connections between clusters and their control plane, NSG rules for the public and private subnets are automatically configured at provisioning time by the Azure Databricks resource provider. You can see these rules in the network security groups "dbricks-public-nsg" and "dbricks-private-nsg" in your Microhack environment.

The cluster nodes are exposed to the public internet and to accept inbound connections on select TCP ports (TCP/22 and TCP/5557). These inbound connections must be handled carefully if you want to customize routing. More specifically, you cannot route them through a firewall NVA, as shown in the picture below. The response traffic (red arrow in the picture) would get Source-NATted behind the NVA's public IP, thus breaking the connection.

![image](images/dbricks-asymmetry.png)



Because of the implications (both in terms of security and routing complexity) of inbound connections from the data plane, Contoso asked to enable [Secure Cluster Connectivity (SCC)](https://docs.microsoft.com/en-us/azure/databricks/security/secure-cluster-connectivity). SCC introduces a relay endpoint in the control plane. VNet-injected clusters establish a connection to the SCC endpoint, which is then used by the control plane to send control messages to the cluster. Control commands still flow from the cluster management element to the cluster, but from a network standpoint the connection is outbound. The network architecture for a VNet-injected Databricks workspace with SCC is shown in the picture below.

![image](images/dbricks-scc.png) 

With SCC, all connections between VNet-injected clusters and the Databricks control plane are outbound and therefore can be routed through a firewall NVA. You will implement this routing policy in the next task, by applying a default route with next hop set to the Azure Firewall's internal IP to the Databricks private and public subnets.

> Routing traffic through additional network hops increases latency. Therefore, customers that do not have strict security requirements may prefer routing connections to some control plane endpoints directly, by means of specific /32 routes. A typical trade-off between security and latency is routing connections to the "SCC relay" and "WebApp" endpoints directly; and connections to the other control plane endpoints (Blob Storage, Metastore, Event Hub, which are the ones that may introduce data exfiltration risks) through a firewall NVA. It should be noted that creating /32 routes for specific endpoints requires knowledge of the endpoint's IP addresses, which is not possible for all Databricks control plane endpoints. Some endpoints are defined only by FQDN. While FQDNs are guaranteed to stay the same, the IP addresses they resolve to may change over time. More on this in the next tasks.

## Task 3: Configure UDRs for the Databricks spoke VNet

As Contoso decided to use Databricks SCC, all control plane connections can be router through a firewall NVA. Therefore, you only need a default route in the custom route table associated to the Databricks subnets. The next hop IP address for the default route must be the IP address of the NVA - in your specific case, the private IP address of the Azure Firewall instance deployed in Challenge 2.

In the Azure portal:

- go to the Overview section for the Azure Firewall deployed in Challenge 2 and note its private IP address:

  ![image](images/firewall-overview.png)

- Find the custom route table resource named "dbricks-spoke-rt" and update the default route with the firewall's IP as the next hop IP address:

  ![image](images/dbricks-udrs.png)

## Task 4: Configure Azure Firewall

With the routing configuration created in the previous task, all traffic between VNet-injected clusters and the Databricks control plane will go through Azure Firewall.

The following table summarizes the [documented](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/udr#ip-addresses) dependencies for a VNet-injected Databricks cluster and provides, for each control plane endpoint,  the required Azure Firewall rules. There is a Databricks control plane implementation in every Azure region where service is available, with its own IP addresses and FQDNs. The table provides, as an example, IPs and FQDNs for West Europe. Please refer to the [official documentation](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/udr#ip-addresses) if you deployed your Microhack environment in a different region. The DBFS Root Blob endpoint is specific for each workspace (it is not a multitenant object: It is created in the customer's subscription when the workspace is provisioned).

![image](images/dbricks-endpoints.png)

> Using firewall NVAs that support FQDN-based rules is strongly recommended for securing Databricks control plane traffic. Although it is technically possible to resolve FQDNs and to create IP-based rules, there is no guarantee that the IP addresses associated to endpoints defined by FQDN do not change over time. Security rules based on IP addresses obtained by resolving FQDNs should be reviewed on a regular basis (preferably using a periodic job to resolve the FQDNs and keep the rules up to date).

In Azure Databricks, the Metastore is implemented on top of Azure DB for MySQL. This makes it impossible to define firewall rules for the Metastore endpoint using Azure Firewall application rules (which only support the HTTP/S and MSSQL protocols). Therefore, you will use FQDN-based network rules.  FQDN-based network rules require configuring Azure Firewall as a DNS proxy. In the Azure portal, go to your Firewall instance and configure DNS settings as shown in the picture below:

![image](images/dns-proxy-azfw.png)

Now set Azure Firewall as the custom DNS server for the dbricks-spoke-vnet:

![image](images/vnet-custom-dns.png)

You are now ready to define the security rules.

If you deployed your Microhack environment in Azure West Europe, a script is available to automatically create the required rules (discussed above). To run the script:

  `cd internet-outbound-microhack/scripts`

  `./dbricks-firewall-rules.ps1 -AzFwName <your Azure Firewall name>`

If you deployed in another region, you need to create the rules manually, using the IP addresses and FQDNs provided in the public documentation. More specifically:

- Find the FQDN for the SCC Relay and the IP address(es) for the WebApp endpoints in your region [here](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/udr#control-plane-nat-and-webapp-ip-addresses)
- Find the FQDNs for the Metastore, Artifact Blob Storage, Log Blob Storage and Event Hub endpoints in your region [here](https://docs.microsoft.com/en-us/azure/databricks/administration-guide/cloud-configurations/azure/udr#--metastore-artifact-blob-storage-log-blob-storage-and-event-hub-endpoint-ip-addresses)
- To get the domain name of DBFS root Blob storage, go to the managed  resource group for the Databricks workspace, find a storage account with the name  in the format `dbstorage************`, and then find its Blob Service Endpoint. The domain name is in the format `dbstorage************.blob.core.windows.net`

## Task 5: Create a cluster and test connectivity with the control plane

In this task, you will deploy a VNet-injected Databricks cluster in the dbricks-spoke-vnet and execute some simple tasks in a notebook to verify connectivity.

In the Azure portal, find the Databricks workspace resource named "dbricks-wksp" (deployed in the resource group named "internet-outbound-microhack-dbricks-rg") and launch the workspace:

![image](images/dbricks-wksp.png)

In the Databricks Web App, create a new cluster:

- click on the "Clusters" button
- enter a name for your cluster
- disable autoscaling
- set the number of worker nodes to 2
- click on the "Create cluster" button

![image](images/create-dbricks-cluster.png)

When the cluster is ready, click on its name and then on the menu item "Spark Cluster UI". Verify that the cluster is reported to be healthy (green dot to the left of the cluster name) and that the details of the worker nodes are displayed.

![image](images/cluster-ui.png)

## Task 6: Resolve connectivity issues

In this task you will learn how to examine Azure Firewall logs to resolve connectivity issues in VNet-injected Databricks clusters. As an example, you will update your firewall rules to allow access to a collection of data files that are often used in Databricks getting started guides (aka "databricks-datasets").  The approach is essentially a trial-and-error process (run a job => query firewall logs to find dropped connections => update firewall rules accordingly) that can be applied to allow access to any data source whose endpoints are not clearly documented/known in advance.  

An Azure Log Analytics workspace has been provisioned in your Microhack environment. Its name follows the pattern `internet-outbound-microhack-workspace-************`. In the Azure portal, go to your Azure Firewall configuration pane and:

- click on the "Diagnostic Settings" menu item

- create a diagnostic settings configuration to send all log messages to the Log Analytics workspace, as shown in the picture below:

  ![image](images/fw-diagnostic-settings.png)

Now run the "Databricks Quickstart" notebook:

![image](images/dbricks-quickstart.png)

You will notice that "Cmd 5" in the notebook (Step 3 in the figure above) does not complete successfully. Go back to the Log Analytics workspace and run the following query to find all connections being blocked by Application Rules in Azure Firewall:

`AzureDiagnostics`
`| where Category  contains "AzureFirewallApplication" and msg_s contains "request from 10.60" and msg_s contains "Action: Deny"`
`| order by TimeGenerated desc` 
`| project TimeGenerated, msg_s`

The query output shows that the cluster is trying to connect to https://sts.amazonaws.com:443. Your Azure Firewall does not have a rule that allows such connection and therefore drops it. 

![image](images/dropped-connections-1.png) 

It turns out that the DBFS path "/databricks-datasets" referenced in the notebook cell you are trying to execute is the mount point  for an external AWS S3 storage blob. In the Azure Portal, go to your Azure Firewall instance and

- click on the "Rules" menu item
- click on "Application Rule Collections"
- click on the "Databricks-rules" collection
- add an application rule to allow connections to  https://sts.amazonaws.com:443 as show in the picture below:

![image](images/dbricks-datasets-rules-1.png)

- click on the "Save" button to update your firewall configuration.

When the firewall configuration is updated, try and execute "Cmd 5" in the quickstart notebook. This time, execution hangs and an error message is returned after a few minutes. To investigate what is going wrong, re-run the query in the Log Analytics workspace:

![image](images/dropped-connections-2.png)

The logs show that Azure Firewall is now blocking access to https://databricks-datasets-oregon.s3.amazonaws.com:443. Repeat the same steps as above to update your firewall configuration and allow access to this URL. When the firewall configuration is updated, try and execute "Cmd 5" in the quickstart notebook again. The cell does not complete successfully, once again. By re-running the query on the firewall logs, you find out that it is now blocking access to https://databricks-datasets-oregon.s3-us-west-2.amazonaws.com:443. Update the firewall configuration accordingly. 

Now you can successfully execute "Cmd 5". Proceed and run "Cmd 6" and "Cmd 7" too. When done, use the "Data" button in the Databricks WebApp to inspect the Metastore ("Database tables") and the DBFS. Confirm that the table "diamonds" created in "Cmd 5" exists. Confirm that the DBFS path "dbfs:/delta/diamonds" has been populated as per "Cmd 7". You have now confirmed that your cluster can access the Metastore and the DBFS Root storage.

## :checkered_flag: Results

You deployed Azure Databricks in a VNet whose routing configuration is under Contoso's control. By enabling the recently released "Secure Cluster Connectivity" option on the workspace, Contoso could route all traffic to/from the cluster nodes through Azure Firewall. 

# Finished? Delete your lab

- Delete the resource group internet-outbound-microhack-rg
- Delete the resource group internet-outbound-microhack-dbricks-rg

Thank you for participating in this MicroHack!

  




