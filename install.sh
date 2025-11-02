#!/bin/sh

echo "eFinder cli install"
echo " "
echo "*****************************************************************************"
echo "Updating Pi OS & packages"
echo "*****************************************************************************"
sudo apt update && sudo apt upgrade -y
echo " "
echo "*****************************************************************************"
echo "Installing additional Debian and Python packages"
echo "*****************************************************************************"
sudo apt install -y \
    python3-pip python3-serial python3-psutil python3-pil python3-pil.imagetk \
    git python3-smbus python3-picamera2 python3-scipy samba samba-common-bin \
    apache2 php8.2

HOME=/home/efinder
cd $HOME
echo " "

python -m venv /home/efinder/venv-efinder --system-site-packages
/home/efinder/venv-efinder/bin/pip install \
    adafruit-circuitpython-adxl34x gdown

cd $HOME
echo " "
echo "*****************************************************************************"
echo "Downloading eFinder_cli from AstroKeith GitHub"
echo "*****************************************************************************"
sudo -u efinder git clone https://github.com/AstroKeith/eFinder_cli.git
echo " "

cd $HOME
echo " "
echo "*****************************************************************************"
echo "Unpacking eFinder_cli & configuring"
echo "*****************************************************************************"
echo "tmpfs /var/tmp tmpfs nodev,nosuid,size=10M 0 0" | sudo tee -a /etc/fstab > /dev/null
mkdir /home/efinder/Solver
mkdir /home/efinder/Solver/images
mkdir /home/efinder/uploads
sudo chmod a+rwx /home/efinder/uploads

cp /home/efinder/eFinder_cli/Solver/*.* /home/efinder/Solver
echo "tmpfs /home/efinder/Solver/images tmpfs nodev,nosuid,size=10M 0 0" | sudo tee -a /etc/fstab > /dev/null

if [ "$1" = "--enable-samba" ]; then
    cd $HOME
    echo " "
    echo "*****************************************************************************"
    echo "Installing Samba file share support"
    echo "*****************************************************************************"
    sudo apt install -y samba samba-common-bin
    sudo tee -a /etc/samba/smb.conf > /dev/null <<EOT
[efindershare]
path = /home/efinder
writeable=Yes
create mask=0777
directory mask=0777
public=no
EOT
    username="efinder"
    pass="efinder"
    (echo $pass; sleep 1; echo $pass) | sudo smbpasswd -a -s $username
    sudo systemctl restart smbd
fi

cd $HOME
echo " "
echo "*****************************************************************************"
echo "installing Tetra3 and its databases"
echo "*****************************************************************************"
sudo -u efinder git clone https://github.com/esa/tetra3.git
cd tetra3
/home/efinder/venv-efinder/bin/pip install .
cd $HOME
sudo venv-efinder/bin/gdown  --output /home/efinder/venv-efinder/lib/python3.11/site-packages/tetra3/data --folder https://drive.google.com/drive/folders/1uxbdttpg0Dpp8OuYUDY9arYoeglfZzcX

echo " "
echo "*****************************************************************************"
echo "Setting up web page server"
echo "*****************************************************************************"
#sudo chmod a+rwx /home/efinder # DO NOT CHANGE THE PERMISSIONS OF THE HOME FOLDER THIS BREAKS SSH Auth
sudo chmod a+rwx /home/efinder/Solver/images
sudo mv /var/www/html /var/www/html.orig
sudo ln -sf /home/efinder/eFinder_cli/Solver/www/site/* /var/www/html/
sudo ln -sf /home/efinder/eFinder_cli/Solver/www/phpini/user.ini /etc/php/8.2/apache2/conf.d/user.ini
sudo ln -sf /home/efinder/eFinder_cli/Solver/www/phpini/user.ini /etc/php/8.2/cli/conf.d/user.ini
sudo chmod -R 755 /var/www/html

cd $HOME
echo " "
echo "*****************************************************************************"
echo "Final eFinder_cli configuration setting"
echo "*****************************************************************************"

sudo tee -a /boot/firmware/config.txt > /dev/null <<EOT
dtoverlay=dwc2,dr_mode=peripheral
enable_uart=1
EOT

sudo python /home/efinder/Solver/cmdlineUpdater.py

sudo chmod a+rwx eFinder_cli/Solver/my_cron
sudo cp /home/efinder/eFinder_cli/Solver/my_cron /etc/cron.d

echo 'vm.swappiness = 0' | sudo tee -a /etc/sysctl.conf > /dev/null
sudo raspi-config nonint do_boot_behaviour B2
sudo raspi-config nonint do_ssh 0
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_serial_cons 1

sudo python /home/efinder/Solver/configUpdater.py
sudo cp newconfig.txt /boot/firmware/config.txt

cd $HOME
echo " "
echo "*****************************************************************************"
echo "Setting up wifi"
echo "*****************************************************************************"
sudo python /home/efinder/Solver/setssid.py

sudo reboot now

