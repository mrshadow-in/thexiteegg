#!/bin/ash
# Paper Installation Script
#
# Server Files: /mnt/server
apt install python
apt install python3
apt install pip
pip install gdown
gdown https://drive.google.com/uc?id=10Q-qTcFGP2byQc9cWco9JwMfPZX9P1Pj
tar -xzvf bedwars.tar.gz
ls
wget https://raw.githubusercontent.com/XD-UrDaD/thexiteegg/main/gstart.sh
mv gstart.sh start.sh
bash start.sh 
