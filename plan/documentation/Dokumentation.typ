
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
    (version: "v1.0", datum: "25.02.2025", autor: "Bastian Uhlig", aenderung: "Erstellung des Dokuments"),
  )
)
= Netzplan
#image("../Netzplan/Netzplan.png")

= ISP 1

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
#table(
  columns: (1fr, auto),
  inset: 10pt,
  align: left+horizon,
  //table.header([], [],),
  [Domain], [wien.FruUhl.at],
)

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



Overlay Netz : MPLS

Netz: 10.0.1.0 - 10.0.1.18 /31

Loopbacks für BGP: 10.0.1.101 - 10.0.1.104 /32

Bogon Filter auf den public Interfaces

Ein VRF auf Border 3 & Border 4 um Standort Rennweg mit Graz zu verbinden. Dazu werden die privaten Netzte der beiden Standorte mit OSPF verteilt und anschließend über BGP weiterverteilt.
