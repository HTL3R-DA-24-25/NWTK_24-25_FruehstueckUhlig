
#import "@htl3r/project-document:0.1.0": *
#import "@preview/htl3r-da:0.1.0" as htl3r
#show: doc => conf(
  doc,
  title: [NTP und FTP in GNS3 testen],
  projekttitel: "Big Topo",
  auftraggeber: ("SDO", "KUS"),
  auftragnehmer: ("Bastian Uhlig",),
  schuljahr: "2024/25",
  klasse: "5CN",
  inhaltsverzeichnis: true,
  enumerate: true,
  versions: (
    (version: "v1.0", datum: "12.03.2025", autor: "Bastian Uhlig", aenderung: "Erstellung des Dokuments"),
    (version: "v1.1", datum: "12.03.2025", autor: "Linuns Frühstück", aenderung: "ISP1"),
  )
)
= Netzplan
#image("../Netzplan/Netzplan.png")

= ISP 1
== Plan

#image("../Netzplan/Netzplan-ISP1.png")

== Allgemeine Informationen

- 4 Border Router
- 3 Backbone Router
- 1 Switch

IGP: OSPF

Overlay Netz : MPLS

Netz: 10.0.1.0 - 10.0.1.18 /31

Loopbacks für BGP: 10.0.1.101 - 10.0.1.104 /32

Bogon Filter auf den public Interfaces

Ein VRF auf Border 3 & Border 4 um Standort Rennweg mit Graz zu verbinden. Dazu werden die privaten Netzte der beiden Standorte mit OSPF verteilt und anschließend über BGP weiterverteilt.

== Grundkonfig

Die Grundkonfiguration ist auf allen Geräten gleich.

 ```bash
 !-----------------
 ! Name des Geräts
 !-----------------

 ! Grundkonfiguration (Basic Configuration)

 en                          ! Enter enable mode
 conf t                      ! Enter global configuration mode
 hostname Name_des_Geraets   ! Set the hostname of the device

 ip domain-name Lil-BT_FRU_UHL ! Define the domain name
 username cisco priv 15 algo sc sec cisco
 ! Create a local user "cisco" with privilege level 15 (full access)
 ! 'algo sc sec' specifies password encryption (scrypt)
 ! Password is set to 'cisco'

 no ip domain-lo ! (This command is to disable domain lookup)
 crypto key generate rsa us mod 1024

 ! Generate an RSA key for SSH with a 1024-bit modulus
 ip ssh version 2 ! Enforce SSH version 2 for secure remote access
 service password-enc ! Enable encryption of plaintext passwords
 mpls ip ! Enable MPLS (Multiprotocol Label Switching) on the device

 ! Configure Virtual Terminal (VTY) lines for remote access
 line vty 0 924
 logg sync ! Synchronize log messages with command output
 transport input ssh ! Allow only SSH for remote access (no Telnet)
 login local ! Use local user authentication
 exec-time 0 ! Disable automatic timeout
 exit

 ! Configure Console line settings
 line con 0
 logg sync ! Synchronize log messages with command output
 no login ! Allow console access without login
 exec-time 0 ! Disable automatic timeout
 exit

 end
 ```

== Interfaces

Hier als Beispiel die Interfaces des Border Router 1.

 ```bash
 !-----------------
 ! Interfaces Konfiguration
 !-----------------

 conf t ! In den globalen Konfigurationsmodus wechseln

 ! GigabitEthernet0/0 - Verbindung zu ISP1-BB1
 int g0/0

    desc to_ISP1-BB1  ! Beschreibung der Schnittstelle
    ip add 10.0.1.0 255.255.255.254  ! IP-Adresse mit einer /31-Subnetzmaske (Point-to-Point)
    mpls ip  ! MPLS aktivieren
    ip ospf authentication key-chain OSPF  ! OSPF-Authentifizierung mit einer Key-Chain
    no shut  ! Schnittstelle aktivieren

 exit

 ! GigabitEthernet0/1 - Verbindung zu ISP1-BB2
 int g0/1

    desc to_ISP1-BB2  ! Beschreibung der Schnittstelle
    ip add 10.0.1.2 255.255.255.254  ! IP-Adresse mit einer /31-Subnetzmaske (Point-to-Point)
    mpls ip  ! MPLS aktivieren
    ip ospf authentication key-chain OSPF  ! OSPF-Authentifizierung mit einer Key-Chain
    no shut  ! Schnittstelle aktivieren

 exit

 ! GigabitEthernet0/2 - Verbindung zu Standort 1
 int g0/2

    desc to_Standort1  ! Beschreibung der Schnittstelle
    ip add 103.152.126.1 255.255.255.248  ! IP-Adresse mit einer /29-Subnetzmaske (6 nutzbare Hosts)
    mpls ip  ! MPLS aktivieren
    ip access-group BLOCK_PRIVATE_AND_LOOPBACK in  ! ACL zur Blockierung von privaten und Loopback-Adressen im eingehenden Verkehr
    no shut  ! Schnittstelle aktivieren

 exit

 ! Loopback1 - Loopback für BGP
 int lo1

    desc loopback_for_BGP  ! Beschreibung der Loopback-Schnittstelle
    ip add 10.0.1.101 255.255.255.255  ! IP-Adresse für die Loopback-Schnittstelle (/32-Subnetzmaske)
    no shut  ! Schnittstelle aktivieren

 end
 ```

== Bogon Block ACL

 ```bash
 conf t

 ip access-list extended BLOCK_PRIVATE_AND_LOOPBACK
     deny ip 10.0.0.0 0.255.255.255 any  # Blockiert den gesamten 10.0.0.0/8-Bereich (privates Netzwerk)
     deny ip 172.16.0.0 0.15.255.255 any  # Blockiert den 172.16.0.0/12-Bereich (privates Netzwerk)
     deny ip 192.168.0.0 0.0.255.255 any  # Blockiert den 192.168.0.0/16-Bereich (privates Netzwerk)
     deny ip 127.0.0.0 0.255.255.255 any  # Blockiert den gesamten 127.0.0.0/8-Bereich (Loopback-Adressen)
     permit ip any any  # Erlaubt allen anderen Traffic
 end
 ```
 
== OSPF

Über OSPF werden die Netzte zwischen den Routern synchronisiert und die Loopbacks für BGP verteilt. Der Austausch findet zwischen allen Routern statt und ist verschlüsselt.

 ```bash
 ! Keychains-Konfiguration für OSPF-Authentifizierung
 conf t

 key chain OSPF  # Erstellt eine Keychain für OSPF
     key 1  # Definiert den ersten Schlüssel in der Keychain
         cryptographic-algorithm hmac-sha-512  # Setzt den Verschlüsselungsalgorithmus auf HMAC-SHA-512
         key-string OSPFSECRETKEY  # Legt den geheimen Schlüssel für die Authentifizierung fest
 end

 ! OSPF-Routing-Protokoll Konfiguration
 conf t

 router ospf 1  # Erstellt den OSPF-Prozess mit der ID 1
     router-id 10.0.1.0  # Setzt die OSPF-Router-ID auf 10.0.1.0

     network 10.0.1.0 0.0.0.1 area 1  # Fügt das Netz 10.0.1.0/31 in Area 1 hinzu
     network 10.0.1.2 0.0.0.1 area 1  # Fügt das Netz 10.0.1.2/31 in Area 1 hinzu

     network 10.0.1.101 0.0.0.0 area 1  # Fügt die Loopback-Schnittstelle 10.0.1.101 in Area 1 hinzu
 end  # Beendet den Konfigurationsmodus
 ```

== BGP

Es gibt eine BGP Beziehung zwischen allen den Border Routern. Die Loopnacks werden als Source genommen damit man nicht von einem Physichen Interface abhängig ist. Es werden auch die public Netzte über BGP bekanntgegeben.

 ```bash
 ! BGP-Konfiguration
 conf t

 router BGP 1  # Aktiviert den BGP-Prozess mit der AS-Nummer 1
     network 103.152.126.0 mask 255.255.255.248  # Fügt das Netzwerk 103.152.126.0/29 in die BGP-Routing-Tabelle ein

     neighbor 10.0.1.102 remote-as 1  # Definiert einen BGP-Nachbarn (10.0.1.102) mit der AS-Nummer 1
     neighbor 10.0.1.102 update-source lo1  # Setzt die Quelle für BGP-Updates auf die Loopback-Schnittstelle lo1

     neighbor 10.0.1.103 remote-as 1  # Definiert einen weiteren BGP-Nachbarn (10.0.1.103) mit der AS-Nummer 1
     neighbor 10.0.1.103 update-source lo1  # Setzt auch hier die Quelle für BGP-Updates auf lo1

     neighbor 10.0.1.104 remote-as 1  # Definiert einen weiteren BGP-Nachbarn (10.0.1.104) mit der AS-Nummer 1
     neighbor 10.0.1.104 update-source lo1  # Setzt die Quelle für BGP-Updates auf lo1
 end  # Verlasse den Konfigurationsmodus
 ```

== VRF

 ```bash
 ! VRF-Konfiguration
 conf t

 ip vrf rennweg-graz  # Erstellt eine VRF mit dem Namen "rennweg-graz"
     rd 1:10  # Definiert den Route Distinguisher (RD) für die VRF
     route-target export 1:10  # Setzt den Route Target (RT) für den Export auf 1:10
     route-target export 1:20  # Setzt den Route Target (RT) für den Export auf 1:20
     route-target import 1:10  # Setzt den Route Target (RT) für den Import auf 1:10
     route-target import 1:20  # Setzt den Route Target (RT) für den Import auf 1:20
 end

 ! Schnittstellen-Konfiguration für VRF
 int g0/2
     desc vrf_to_Standort2  # Beschreibung der Schnittstelle
     ip vrf forward rennweg-graz  # Weist die Schnittstelle der VRF "rennweg-graz" zu
     ip add 10.10.10.1 255.255.255.248  # IP-Adresse und Subnetzmaske für die Schnittstelle
     mpls ip  # Aktiviert MPLS auf der Schnittstelle
     no shut  # Aktiviert die Schnittstelle
 exit

 ! Distribution List
 ip prefix-list BLOCK_NET seq 10 deny 192.168.53.0/24  # Blockiert das Netzwerk 192.168.53.0/24
 ip prefix-list BLOCK_NET seq 20 permit 0.0.0.0/0 le 32  # Erlaubt alle anderen IPs

 ! OSPF mit VRF und Prefix-Filter
 router ospf 10 vrf rennweg-graz  # Aktiviert OSPF in der VRF "rennweg-graz"
     redistribute connected subnets  # Redistribuiert verbundene Netzwerke und Subnetze
     distribute-list prefix BLOCK_NET in  # Wendet die Prefix-List "BLOCK_NET" auf eingehende Routen an
     network 10.10.10.0 0.0.0.7 area 1  # Definiert das OSPF-Netzwerk in Area 1
 end

 ! BGP-Konfiguration für VRF
 router BGP 1
     address-family vpnv4  # Aktiviert das vpnv4 Adressfamilien-Protokoll
         nei 10.0.1.104 activate  # Aktiviert den BGP-Nachbarn 10.0.1.104 für vpnv4
         nei 10.0.1.104 send-community extended  # Aktiviert das Senden von erweiterten Communities zu diesem Nachbarn

     address-family ipv4 vrf rennweg-graz  # Aktiviert die IPv4-Adressenfamilie für die VRF "rennweg-graz"
         redistribute ospf 10  # Redistribuiert OSPF-Routen in BGP
 end
 ```

= Standort Wien
== Plan

//#image("../Netzplan/Netzplan-Wien.png")

#table(
  columns: (1fr, auto),
  inset: 10pt,
  align: left+horizon,
  table.header([*Hostname*], [*IP-Adresse*],),
  [_DC-Netzwerk_], [_192.168.10.0/24_],
  [DC1],[192.168.10.1],
  [DC2],[192.168.10.2],
  [CA],[192.168.10.5],
  [Web],[192.168.10.6],
  [DFS],[192.168.10.10],
  [_Server-Netzwerk_], [_192.168.0.0/24_],
  [Syslog],[192.168.0.1],
  [Mirror],[192.168.0.2],
  [Netflow],[192.168.0.3],
  [NTP],[192.168.0.4],
  [_Management-Netzwerk_], [_192.168.50.0/24_],
  [SW Server],[192.168.50.1],
  [SW AD],[192.168.50.2],
  [SW Abt1],[192.168.50.3],
  [SW Abt2],[192.168.50.4],
  [_Client-Netzwerk_], [_192.168.100.0/24_],
  [Client 1],[DHCP],
  [Client 2],[DHCP],
)
== Allgemeine Informationen
Dies ist der Hauptstandort mit den wichtigsten Active-Directory Komponenten. Auch einige Server-Dienste sind hier angesiedelt, sowie ein HA-Cluster für den Uplink und switching.

== Windows
Dies ist der Haupt-Standort der Domain wien.FruUhl.at. Hier befinden sich die beiden Domaincontroller DC1 und DC2, sowie der Certificate Authority Server CA. Der Webserver ist als CDP in Verwendung und auf dem DFS-Server sind mehrere Freigaben für die Benutzer vorhanden.\
Das Active-Directory Gruppen-Prinzip ist nach AGUDLP aufgebaut, die OUs nach Business Unit Model. 

== Switching
Die verschiedenen Netzwerke werden mittels
= Standort Rennweg
== Plan
//#image("../Netzplan/Netzplan-Rennweg.png")
#table(
  columns: (1fr, auto),
  inset: 10pt,
  align: left+horizon,
  table.header([*Hostname*], [*IP-Adresse*],),
  [_Server-Netzwerk_], [_172.16.100.0/24_],
  [DC],[172.16.100.1],
  [Jumphost],[172.16.100.100]
)
== Allgemeine Informationen
Rennweg ist eine 2. Site der wien.FruUhl.at Domain. Der Domaincontroller hier ist ein Read-Only Domaincontroller. Der Jumphost ist für die Administration des Servers zuständig, denn nur über ihn kann eine RDP-Session aufgebaut werden.

= Standort Graz
== Plan
//#image("../Netzplan/Netzplan-Graz.png")
#table(
  columns: (1fr, auto),
  inset: 10pt,
  align: left+horizon,
  table.header([*Hostname*], [*IP-Adresse*],),
  [_AD-Netzwerk_], [_172.16.0.0/24_],
  [DC],[172.16.0.1],
  [LinCli],[172.16.0.10],
  [_Server-Netzwerk_], [_172.16.10.0/24_],
  [Grafana],[172.16.10.10 - 103.152.126.35 nach außen],
  [bind9],[172.16.10.20],
)
== Allgemeine Informationen
Graz ist eine Sub-Domain der wien.FruUhl.at Domain. Auf dem Standort befindet sich weiters ein Active Directory gejointer Linux Client. Der DNS-Server bind9 wird als caching Forwarder verwendet und auf dem Grafana-Dashboard sind Statistiken der Serverauslastung zu sehen, welche mittels Prometheus gesammelt werden. Der Server wird auch statisch nach außen genattet, womit er public erreichbar ist.


