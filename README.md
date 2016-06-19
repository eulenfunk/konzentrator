# Skripte für den Konzentrator

(!) Work in Progress: Use at own risk (!)

* Netzwerkkonfiguration für die Supernodes werden unter /opt/eulenfunk/konzentrator/config abgelegt
* In rc.local wird /opt/eulenfunk/konzentrator/bgp-konzentrator-rc.sh aufgerufen
* Supernode-Konfigurationen können mit /opt/eulenfunk/konzentrator/supernode.sh gesetzt und entfernt werden:
      
      ./supernode.sh start tollestadt-1

# Konfigurationshelfer für Freifunk BGP-Konzentrator Setup

Das Script *bgp-konzentrator-setup.sh* fragt die nötigen Parameter ab und
erzeugt daraus die Konfigurationsdateien:
  * bird.conf
  * bird6.conf
  * Auszug aus interfaces
  * ferm.conf
  * 20-ff-config.conf (sysctl Parameter)

Es ist möglich in der Datei *bgp-konzentrator.conf* die passenden
Werte einzutragen. Damit ist dann später eine maschinelle
Erstellung der Konfigs möglich.

