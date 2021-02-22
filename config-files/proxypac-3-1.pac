// Contoso basic proxying policy
function FindProxyForURL(url, host)
{
    var direct = "DIRECT";
    var proxyServer = "PROXY 10.57.2.4:3126";

    if(shExpMatch(host, "ipinfo.io")
       || shExpMatch(host, "*.wvd.microsoft.com")
       || shExpMatch(host, "gcs.prod.monitoring.core.windows.net")
       || shExpMatch(host, "production.diagnostics.monitoring.core.windows.net")
       || shExpMatch(host, "*xt.blob.core.windows.net")
       || shExpMatch(host, "*eh.servicebus.windows.net")
       || shExpMatch(host, "*xt.table.core.windows.net")
       || shExpMatch(host, "catalogartifact.azureedge.net")
       || shExpMatch(host, "kms.core.windows.net")
       || shExpMatch(host, "mrsglobalsteus2prod.blob.core.windows.net")
       || shExpMatch(host, "wvdportalstorageblob.blob.core.windows.net")
       || shExpMatch(host, "169.254.169.254")
       || shExpMatch(host, "168.63.129.16")
       || shExpMatch(host, "10.57.2.4"))
    {
        return direct;
    }

    return proxyServer;
}
