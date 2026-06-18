# Inception

## Objective
Create an whole infrastructure (front + back + db) using docker compose and manage multiple containers;

## Requirements
- [ ] Each service runs in a separated container (runs in the penultimate version of alpine/debian)
- [ ] One dockerfile by service -> which is called by docker compose
- [ ] NGINX uses TLSv1.2 or TLS v1.3
- [ ] Wordpress + WordPress + php-fpm (installed and configured) without ngix
- [ ] Mariadb only
- [ ] Docker Volume for the DB of wordpress
- [ ] Second value for fles of wordpress
- [ ] Docker networks to connect containers
- [ ] if it crashes the containers must restart (don't use tail -f) -> study the daemon
- [ ] Wordpress DB must have two users: manager and normar user
- [ ] Volume path should be /home/thaperei/data
- [ ] Domain name: thaperei.42.fr -> local IP address
- [ ] Use .env, it's recomended docker secrets to add confidential info (credentials, api keys, passwords and etc...)
- [ ] The only way to access the infrastructure is by the port 443 (NGIX) using TLSv1.2 or TLSv1.3;

### Prohibited
- host or --link
- bash or sleep infinity or while true

## Recommend
- Read PID1 and read the good practices to write dockerfile
