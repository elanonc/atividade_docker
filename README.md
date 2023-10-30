# Atividade Docker

Repositorio para documentar a atividade de Docker, do programa de bolsas da Compass UOL.

## Requisitos

- Instalação e configuração do DOCKER ou CONTAINERD no host EC2: ponto adicional para instalação via script de Start Instance (user_data.sh);
- Deploy de uma aplicação Wordpress com: container de aplicação RDS database MySQL;
- Configuração da utilização do serviço EFS AWS para estáticos do container da aplicação Wordpress;
- Configuração do serviço de Load Balancer AWS para a aplicação Wordpress.

### Pontos de Atenção:

- Não utilizar IP público para saída do serviço WP (Evitar publicar o serviço WP via IP Público);
- Sugestão para o tráfego de internet: sair pelo LB (Load Balancer Classic);
- Pastas públicas e estáticos do Wordpress: sugestão de utilizar o EFS (Elastic File Sistem);
- Fica a critério de cada integrante usar Dockerfile ou Dockercompose;
- Necessário demonstrar a aplicação Wordpress funcionando (tela de login);
- A aplicação Wordpress precisa estar rodando na porta 80 ou 8080.

### Topologia proposta para a atividade

<div style="text-align: center;">
  <img src="/assets/01-arquitetura.jpg" width="700" alt="Topologia proposta para a atividade">
</div>

## Instruções de Execução

### - Criação e configuração da VPC:

- No serviço VPC no Console da AWS foi criada uma VPC com nome `VPC-compasso-1`.
- Nesta VPC, foram criadas duas subnets na zona da disponibilidade `us-east-1a`, uma pública e a outra privada.
- Também foram foram criadas duas subnets na zona da disponibilidade `us-east-1b`, assim como anteriormente, uma pública e a outra privada.
- Foram criadas duas tabelas de roteamento, uma para as subnets públicas e outra para as subnets privadas.
- Para a tabela de roteamento com as subnets públicas, foi criado um gateway de internet, e então, foi adicionado uma rota para o Internet Gateway.
- Já para a tabela de roteamento com as subnets privadas, foi criado um NAT gateway, e depois foi adicionado uma rota para o NAT Gateway.

Pode-se conferir como ficou a VPC na imagem a seguir:

<div style="text-align: center;">
  <img src="/assets/02-mapa-de-recursos.png" width="700" alt="mapa de recursos da VPC">
</div>

### - Grupos de segurança

- Na seção do EC2, nos grupos de segurança, foram configurados os seguintes grupos:

  | Tipo         | Protocolo | Porta | Origem           |
  | ------------ | --------- | ----- | ---------------- |
  | HTTP         | TCP       | 80    | SG-Load Balancer |
  | NFS          | NFS       | 2049  | SG-EFS           |
  | MYSQL/Aurora | TCP       | 3306  | SG-RDS           |

- Grupo de segurança do Load Balancer:

  | Tipo | Protocolo | Porta | Origem    |
  | ---- | --------- | ----- | --------- |
  | HTTP | TCP       | 80    | 0.0.0.0/0 |

- Grupo de segurança do EFS:

  | Tipo | Protocolo | Porta | Origem    |
  | ---- | --------- | ----- | --------- |
  | NFS  | TCP       | 2049  | 0.0.0.0/0 |

- Grupo de segurança do RDS:

  | Tipo         | Protocolo | Porta | Origem        |
  | ------------ | --------- | ----- | ------------- |
  | MYSQL/Aurora | TCP       | 3306  | 0.0.0.0/0     |
  | MYSQL/Aurora | TCP       | 3306  | SG-Instancias |

### - Configuração do Load Balancer

Para a realização dessa atividade, foi escolhido o Applcation Load Balancer, para poder utilizar a mecânica dos grupos de destino. Então, as configurações do Load Balancer ficaram assim:

- Na seção do EC2, na opção do Load Balancer, clicar em "criar Load Balancer".
- Foram selecionadas as seguintes configurações:
  - Tipo: Application Load Balancer.
  - Esquema: Voltado para a internet.
  - Tipo de endereço IP: "IPv4".
  - Grupo de segurança: SG-Load-Balancer.
  - Listener: grupo de destino criado.

### - Configuração do Grupo de Destino (Target Groupy)

- Foram selecionadas as seguintes configurações:
  - VPC: VPC criada para a atividade.
  - Sub-redes: Sub-redes públicas das duas zonas de disponibilidade disponíveis.
  - Protocolo: "HTTP"
  - Porta: "80" para o listener.
  - Grupo de destino (Target Group): instâncias privadas criadas anteriormente.

### - Configuração do EFS

- Na seção do EFS, foi clicado em "criar sistemas de arquivos".
- Foram selecionadas as seguintes configurações:
  - Nome: EFS-compasso.
  - VPC: VPC criada anteriormente.
  - Grupo de segurança: SG-EFS.

### - Configuração do RDS

- Na seção do RDS, no painel das instâncias, foi clicado em "criar banco de dados".
- Foram selecionadas as seguintes configurações:
  - Metodo de criação: Padrão.
  - Banco de Dados: MYSQL.
  - Versão: 8.0.33.
  - Modelo: nível gratuito.
  - Identificação: db-ufc.
  - Nome de usuário: admin.
  - Instância: t3.micro.
  - Armazenamento: GP3.
  - Conectividade: não se conectar a um recurso de computação do EC2.
  - Tipo de rede: IPV4.
  - VPC: VPC criada anteriormente.
  - Subredes: sub-redes privadas das zonas de disponibilidade `us-east-1a` e `us-east-1b`.
  - Grupo de Segurança: SG-RDS.
  - Zona de disponibilidade: "sem preferência".
  - Autoridade de certificação: padrão.
  - Autenticação: com senha.
  - Senha: admin123.
  - Em configurações adicionais, em nome do banco de dados: dbwordpress.

### - Configuração do Script 'user_data'

Para subir os contêineres responsáveis pela configuração do WordPress, foi criado um arquivo `docker-compose.yml` que foi adicionado no meu github para posteriormente acessa-lo nas instâncias privadas através do script `user_data.sh`.

Segue o arquivo `docker-compose.yml`:

```
version: "3"
services:
  wordpress:
    image: wordpress:latest
    volumes:
      - /mnt/efs/wordpress:/var/www/html
    environment:
      TZ: America/Fortaleza
      WORDPRESS_DB_HOST: db-pbufc.chnab22xelei.us-east-1.rds.amazonaws.com
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: admin123
      WORDPRESS_DB_NAME: dbwordpress
    ports:
      - 80:80
```

Segue o arquivo `user_data.sh`:

```
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
```

### - Configuração do Modelo de Execução (Lauch Template)

Para configurarmos o Auto Scaling, primeiro, precisamos configurar corretametne o Modelo de Execução das máquinas EC2, que irão utilizar o script `user_data.sh`.

- Na seção do EC2, no painel de "Instâncias" em "Modelos de execução" foi clicado na opção de "criar modelo de execução".
- Foram selecionadas as seguintes configurações:
  - Nome: EC2-Compasso.
  - Imagem: Amazon Linux 2.
  - Tipo: t2.micro.
  - Armazenamento: 8 GB SSD.
  - Chave pública para acesso ao ambiente.
  - Grupo de Segurança: SG-Instancias (configurado anteriormente).
  - Utiliza o script `user_data.sh`.

### - Configuração do Auto Scaling

- Na seção do EC2, no painel de "Grupos de Auto Scaling", foi clicado em "Criar grupo do Auto Scaling".
- Foram selecionadas as seguintes configurações:
  - Modelo de execução selecionado: EC2-Compasso.
  - Associação com a VPC criada anteriormente.
  - Associação com as sub-redes privadas das zonas de disponibilidade `us-east-1a` e `us-east-1b`.
  - Associação com o Applcation Load Balancer criado anteriormente.
  - Capacidade desejada = 2, capacidade mínima = 2 e capacidade máxima = 2.

Com essa configuração, todos os requisitos da atividade foram cumpridos.
