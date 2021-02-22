#cloud-config
yum_repos:
  epel:  
    name: Extra Packages for Enterprise Linux $releasever - $basearch
    baseurl: https://download.fedoraproject.org/pub/epel/$releasever/Everything/$basearch
    metalink: https://mirrors.fedoraproject.org/metalink?repo=epel-$releasever&arch=$basearch&infra=$infra&content=$contentdir
    failovermethod: priority
    enabled: 1
    gpgcheck: 0
packages:
  - squid
  - strongswan
  - httpd
write_files:
  - owner: root:root
    append: 1
    path: /etc/strongswan/ipsec.secrets
    content: |
      ${hub-vpngw-pip} : PSK ${shared-key}
  - owner: root:root
    append: 1
    path: /etc/strongswan/ipsec.conf
    content: |
      config setup
      conn toHub
       right=${hub-vpngw-pip}
       rightsubnet=10.58.0.0/16,10.59.0.0/16
       leftid=${proxy-vm-pip}
       leftsubnet=0.0.0.0/0
       keyexchange=ikev2
       authby=secret
       ike=aes128-sha256-modp1024
       dpdaction=restart
       auto=start
  - owner: root:root
    append: 0
    path: /etc/sysctl.d/90-sysctl.conf
    content: |
      net.ipv4.conf.all.forwarding=1
runcmd:
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/httpd.conf --output /etc/httpd/conf/httpd.conf
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/O365-optimize.pac --output /var/www/html/O365-optimize.pac
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/proxypac-3-1.pac --output /var/www/html/proxypac-3-1.pac
  - systemctl enable --now httpd
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/squid.conf --output /etc/squid/squid.conf
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/contoso-urls.conf --output /etc/squid/contoso-urls.conf
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/O365-urls.conf --output /etc/squid/O365-urls.conf
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/access-denied.htm --output /var/www/html/access-denied.htm
  - mkdir /etc/squid/ssl_certs
  - chown squid:squid /etc/squid/ssl_certs
  - chmod 700 /etc/squid/ssl_certs
  - openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -extensions v3_ca -subj "/C=IT/CN=Contoso Enterprise CA" -keyout /etc/squid/ssl_certs/contosoCA.pem  -out /etc/squid/ssl_certs/contosoCA.pem
  - setenforce 0
  - mkdir -p /var/lib/squid
  - rm -rf /var/lib/squid/ssl_db
  - /usr/lib64/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 20MB
  - chown -R squid:squid /var/lib/squid
  - systemctl enable --now squid
  - strongswan start
  - sysctl -w net.ipv4.conf.all.forwarding=1
  - curl https://raw.githubusercontent.com/fguerri/internet-outbound-microhack/main/config-files/iptables.conf --output /home/adminuser/iptables.conf
  - iptables-restore /home/adminuser/iptables.conf
