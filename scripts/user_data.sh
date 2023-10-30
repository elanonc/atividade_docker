#!/bin/bash

# Atualizando o sistema
yum update -y

# Instalação e configuração do docker
sudo yum install docker -y
sudo systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Configurando permissões do socket do Docker
chmod 666 /var/run/docker.sock

# Instalação do docker-compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalação do cliente nfs
yum install nfs-utils -y

# Montagem do efs
mkdir -p /mnt/efs
chmod +rwx /mnt/efs/
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0fa539d3c5e3db1ef.efs.us-east-1.amazonaws.com:/ /mnt/efs/
echo "fs-0fa539d3c5e3db1ef.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs defaults 0 0" >> /etc/fstab

# Executando o docker-compose do repositorio
curl -sL "https://raw.githubusercontent.com/elanonc/atividade_docker/main/docker-compose.yml" --output "/home/ec2-user/docker-compose.yml"
docker-compose -f /home/ec2-user/docker-compose.yml up -d