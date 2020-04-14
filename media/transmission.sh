sudo add-apt-repository ppa:transmissionbt/ppa
sudo apt-get update
sudo apt-get install transmission-cli transmission-common transmission-daemon
#modify username/password/settings in /var/lib/transmission-daemon/info/settings.json
# ufw allow 9091
# see https://help.ubuntu.com/community/TransmissionHowTo
N
ROOT_DIR=/home/one/services/transmission

mkdir -p ${ROOT_DIR}
mkdir -p ${ROOT_DIR}/config
mkdir -p ${ROOT_DIR}/downloads
mkdir -p ${ROOT_DIR}/watch

