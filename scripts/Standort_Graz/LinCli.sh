sudo apt update
sudo apt install realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

sudo realm discover wien.FruUhl.at
sudo realm join wien.FruUhl.at -U Administrator

sudo systemctl restart sssd

sudo pam-auth-update # enable mkhomedir

sudo nano /etc/gdm3/custom.conf # AllowAccountsFromDomain = true