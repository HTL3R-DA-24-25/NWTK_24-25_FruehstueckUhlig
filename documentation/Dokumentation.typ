
#import "@htl3r/project-document:0.1.0": *

#show: doc => conf(
  doc,
  title: [Little Big Topo Dokumentation],
  projekttitel: "Little Big Topo",
  auftraggeber: ("SDO", "KUS"),
  auftragnehmer: ("Linus Frühstück, Bastian Uhlig",),
  schuljahr: "2024/25",
  klasse: "5CN",
  inhaltsverzeichnis: true,
  enumerate: true,
  versions: (
    (version: "v1.0", datum: "12.03.2025", autor: "Bastian Uhlig", aenderung: "Erstellung des Dokuments"),
    (version: "v1.1", datum: "12.03.2025", autor: "Linus Frühstück", aenderung: "ISP1"),
    (version: "v1.2", datum: "13.03.2025", autor: "Linus Frühstück", aenderung: "ISP2"),
    (version: "v1.3", datum: "13.03.2025", autor: "Bastian Uhlig", aenderung: "AD Dokumentation"),
    (version: "v1.4", datum: "13.03.2025", autor: "Linus Frühstück", aenderung: "Firewalls"),
  )
)

#page(flipped: true)[
  #grid(
    columns: 1fr,
    rows: (20pt, 1fr),
  [= Netzplan],
  align(center)[#image("../plan/Netzplan/Netzplan.png")]
  )
]

= ISP 1
== Plan
#image("../plan/Netzplan/Netzplan-ISP1.png")

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

= ISP 2
== Plan
#image("../plan/Netzplan/Netzplan-ISP2.png")
== Allgemeine Informationen

- 3 Border Router
- 3 Backbone Router

IGP: OSPF

Overlay Netz : DMVPN

Netz: 10.0.2.0 - 10.0.2.16 /31

Loopbacks für BGP: 10.0.2.101 - 10.0.2.103 /32

Loopbacks für den DMVPN: 10.0.2.111 - 10.0.2.113 /32

Bogon Filter auf den public Interfaces

Eine default Route, die via BGP weitergegeben wird.

== Grundkonfig

Siehe ISP1

== Interfaces

```bash
!Interfaces
conf t

! Interface zur Verbindung mit ISP2-BB2
int g0/0
    desc to_ISP2-BB2
    ip add 10.0.2.0 255.255.255.254  ! Setzt die IP-Adresse mit einer /31-Subnetzmaske
    ip ospf authentication key-chain OSPF  ! Aktiviert die OSPF-Authentifizierung
    no shut  ! Aktiviert das Interface
exit

! Interface zur Verbindung mit ISP2-BB1
int g0/1
    desc to_ISP2-BB1
    ip add 10.0.2.2 255.255.255.254  ! Setzt die IP-Adresse mit einer /31-Subnetzmaske
    ip ospf authentication key-chain OSPF  ! Aktiviert die OSPF-Authentifizierung
    no shut  ! Aktiviert das Interface
exit

! Interface zur Verbindung mit Standort1
int g0/2
    desc to_Standort1
    ip add 103.152.126.17 255.255.255.248  ! Setzt die IP-Adresse mit einer /29-Subnetzmaske
    ip access-group BLOCK_PRIVATE_AND_LOOPBACK in  ! Filtert privaten und Loopback-Traffic
    no shut  ! Aktiviert das Interface
exit

! Loopback-Interface für BGP
int lo1
    desc loopback_for_BGP
    ip add 10.0.2.101 255.255.255.255  ! Setzt eine /32-IP für BGP
    no shut  ! Aktiviert das Interface
exit

! Loopback-Interface für Tunnel
int lo2
    desc for_tunnel
    ip add 10.0.2.111 255.255.255.255  ! Setzt eine /32-IP für Tunnelverbindungen
    no shut  ! Aktiviert das Interface
exit
```

== Bogon Block ACL

Siehe ISP 1

== OSPF

Es gibt zwei OSPF Prozesse.
Der erste ist um die Netzte zwischen den Routern für OSPF zu aktivieren und die Loopbacks für die Tunnel auszutauschen.
Der zweite Prozess dient dazu, über das DMVPN die Loopbacks für BGP auszutauschen.

```bash
! Keychains-Konfiguration für OSPF-Authentifizierung
conf t

key chain OSPF  # Erstellt eine Keychain für OSPF
    key 1  # Definiert den ersten Schlüssel in der Keychain
        cryptographic-algorithm hmac-sha-512  # Setzt den Verschlüsselungsalgorithmus auf HMAC-SHA-512
        key-string OSPFSECRETKEY  # Legt den geheimen Schlüssel für die Authentifizierung fest
end

!OSPF
conf t

! OSPF-Prozess 1 - Primärer OSPF-Router für Area 1
router ospf 1
router-id 10.0.2.0 ! Setzt die eindeutige Router-ID für OSPF 1

    network 10.0.2.0 0.0.0.1 area 1  ! Fügt das Netzwerk 10.0.2.0/31 zu Area 1 hinzu
    network 10.0.2.2 0.0.0.1 area 1  ! Fügt das Netzwerk 10.0.2.2/31 zu Area 1 hinzu
    network 10.0.2.111 0.0.0.0 area 1  ! Fügt die Loopback-Adresse 10.0.2.111/32 zu Area 1 hinzu

exit

! OSPF-Prozess 2 - Zweiter OSPF-Prozess für Area 2
router ospf 2
router-id 10.0.2.111 ! Setzt die eindeutige Router-ID für OSPF 2

    network 101.100.12.0 0.0.0.255 area 2  ! Fügt das Netzwerk 101.100.12.0/24 zu Area 2 hinzu
    network 10.0.2.101 0.0.0.0 area 2  ! Fügt die Loopback-Adresse 10.0.2.101/32 zu Area 2 hinzu

end
```

== BGP

Siehe ISP 1

== DMVPN

Es gibt einen DMVPN zwischen den drei Border Routern. Dieser dient als Overlay Netzwerk. Der VPN ist verschlüsselt das gleiche gilt auch für den OSPF Prozess, der über das Overlay läuft.

```bash
!Tunnel
int tun1
    desc multipoint_tunnel  ! Beschreibung des Tunnels
    ip add 101.100.12.1 255.255.255.0  ! IP-Adresse und Subnetzmaske für das Tunnelinterface
    tunnel mode gre multipoint  ! GRE-Tunnel im Multipoint-Modus
    tunnel source lo2  ! Quelle des Tunnels ist Loopback 2
    no ip redirects  ! Deaktiviert ICMP-Redirects für Sicherheit
    ip mtu 1440  ! Setzt die maximale Übertragungsgröße für den Tunnel
    ip nhrp authentication cisco123  ! NHRP-Authentifizierung mit Passwort
    ip nhrp map multicast dynamic  ! Erlaubt dynamisches Multicast-Mapping über NHRP
    ip nhrp network-id 1  ! Setzt die Netzwerk-ID für NHRP
    no shut  ! Aktiviert das Interface
exit

!VPN
crypto isakmp policy 10
    encryption aes 256  ! Starke AES-256-Verschlüsselung
    lifetime 86400  ! Lebensdauer des Schlüssels auf 24 Stunden gesetzt
    hash sha512  ! SHA-512 für starke Integritätsprüfung
    group 5  ! Diffie-Hellman Gruppe 5 für Schlüsselaustausch
    authentication pre-share  ! Pre-Shared Key zur Authentifizierung
exit

crypto isakmp key cisco123! address 0.0.0.0  ! Setzt den Pre-Shared Key für alle IP-Adressen

crypto ipsec transform-set 5CN esp-sha512-hmac esp-aes 256
    mode transport  ! Transportmodus für IPSec
exit

crypto ipsec profile IPSEC_PROF
    set transform-set 5CN  ! Verwendet das zuvor erstellte Transform-Set
exit

int tun1
    no ip split-horizon  ! Deaktiviert Split-Horizon, um Routing-Probleme zu vermeiden
    ip nhrp shortcut  ! Aktiviert NHRP-Shortcuts für schnellere Paketweiterleitung
    tunn protection ipsec profile IPSEC_PROF  ! Schützt den Tunnel mit IPSec
    ip ospf network point-to-multipoint  ! Setze das Netz auf OSPF point to multipoint. Dadurch das die Loopbacks für BGP über die Tunnel bekanngegeben werden muss das gesetzt werden. Sonst flappt der Tunnel
    ip ospf authentication key-chain OSPF  ! OSPF-Authentifizierung mit einer Key-Chain
end
```


= Standort Wien
== Plan

#image("../plan/Netzplan/Netzplan-Wien.png")

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
Dies ist der Hauptstandort der Domain wien.FruUhl.at. Hier befinden sich die beiden Domaincontroller DC1 und DC2, sowie der Certificate Authority Server CA. Der Webserver ist sowohl als CDP in Verwendung sowie als Radius-Server zur Authentifizierung bei den Switches des Netzwerkes. Auf dem DFS-Server befinden sind Freigaben für Benutzer, darunter abteilungsweite Shares und die Ablageorte für Roaming-Profiles. \
Das Active-Directory Gruppen-Prinzip ist nach AGUDLP aufgebaut, die OUs nach Business Unit Model. \


=== Gruppen
#image("../plan/AD/Gruppen/Gruppen.png")

=== OUs 
#image("../plan/AD/OUs/OU-Struktur.png")

=== Screenshots
TODO: Screenshot der CA - pkiview.msc
==== Sites
// thx https://www.alkanesolutions.co.uk/2021/02/26/list-ad-sites-and-subnets-using-powershell/


== Switching
Die verschiedenen Netzwerke werden mittels VLANs unterteilt. Hierbei gibt es 5 unterschiedliche:
#table(
  columns: (auto, 1fr),
  inset: 10pt,
  align: left+horizon,
  table.header([*VLAN*], [*Name*],),
  [1],[Server],
  [10],[DC],
  [50],[Management],
  [100],[Clients],
  [200],[RSPAN],
)
=== Spanning Tree 
Auf allen Switches ist per-vlan Spanning Tree konfiguriert, wobei der AD-Switch die Root-Bridge für alle VLANs ist. Zwischen den Switches sind auf den Trunk-Ports immer nur die zwingend notwendigen VLANs erlaubt, beispielsweise ist das RSPAN Netzwerk nur auf den Core-Layer Switches erlaubt. 
=== RSPAN
Das RSPAN-Vlan existiert nur auf den Core-Layer Switches. über dieses wird jeglicher Traffic aus dem AD-Netzwerk gespiegelt und auf den Mirror-Server geleitet, auf welchem mit tshark der Traffic aufgezeichnet und abgespeichert wird.
=== Netflow
Auf dem AD Switch ist ein Flow-Exporter konfiguriert, welcher mittels Netflow allen Traffic aus  dem AD-Netzwerk auf den Netflow-Server leitet. Dieser wertet die Daten aus und stellt sie in einem Dashboard dar.
=== Syslog
Alle Switches sind konfiguriert, ihre Log-Daten an den Syslog-Server zu senden. Dort wird dieser mittels Kiwi Syslog aufgezeichnet. 
=== Authentication
Die Switches sind mittels Radius-Server authentifiziert. Der Radius-Server ist auf dem WEB-Server installiert und konfiguriert, da ein GUI benötigt wird, und dieser Server der einzige mit GUI ist.

== Features FG Wien
- HA Cluster
- NAT/PAT
- Granulare Policies
- Traffic Shaping
- Captive Portal
- DHCP
- Subinterfaces
- Site2Site VPN mit anderer FortiGate
  - (FG Rennweg)
- Site2Site VPN mit PfSense
  - (PF Graz)
- RAS VPN zu WinCli auf IPsec Basis
- Redundanter ISP
  
= Standort Rennweg
== Plan
#image("../plan/Netzplan/Netzplan-Rennweg.png")
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

== Features FG Rennweg
- NAT/PAT
- Site2Site VPN mit anderer FortiGate
  - (FG Wien)
- OSPF um private Netzte für VRF bekanntzugeben
- Distribution Listen um Netze nicht via OSPF zu teilen

= Standort Graz
== Plan
#image("../plan/Netzplan/Netzplan-Graz.png")
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

== Features PF Graz
- NAT/PAT
- Subinterfaces
- Site2Site VPN mit FortiGate
  - (FG Wien)
- OSPF um private Netzte für VRF bekanntzugeben
- Distribution Listen um Netze nicht via OSPF zu teilen
- Static NAT
  - Grafana Server
- WireGuard RAS VPN für WinCli

