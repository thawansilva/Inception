# 42 School — Inception Project Roadmap

> **Golden rule:** don't try to do all the containers (NGINX, WordPress, and MariaDB) at the same time. You will be lost and will not understand properly how it works. Do it **step by step**.

---

## Key Rules to Keep in Mind

- **No ready-made images**: forbidden to pull and use ready-made Docker images from DockerHub. Every image must be built from a Dockerfile based on Alpine or Debian (penultimate stable version) only.
- **No passwords in Dockerfiles**: all secrets must come from environment variables via an `.env` file located at `srcs/.env`.
- **WordPress users**: the database must have exactly 2 users — one admin and one regular user. The admin username must NOT contain `admin`, `Admin`, `administrator`, or `Administrator`.
- **Docker Compose is mandatory**: orchestrate everything through a Makefile using `docker compose -f srcs/docker-compose.yml`.

---

## Phase 1 — Learn the Concepts (~2–3 days)

### 1.1 Understand Docker vs VMs `[tip]`
Read about containers, images, layers, and the OCI format. Understand why containers are lighter than VMs and how Linux kernel namespaces/cgroups make them work.

### 1.2 Learn Dockerfile syntax `[mandatory]`
Practice writing simple Dockerfiles based on Alpine or Debian. Understand `FROM`, `RUN`, `COPY`, `CMD`, `ENTRYPOINT`. Build and run them manually.

### 1.3 Learn Docker Compose basics `[mandatory]`
Understand services, volumes, networks, `depends_on`, `env_file`, restart policies. Write a simple compose file with two services.

### 1.4 Understand PID 1 in containers `[mandatory]`
Crucial for the project. Daemons should **not** be run as PID 1. Learn how entrypoint scripts and exec form `CMD` solve this.

### 1.5 Study TLS / SSL basics `[mandatory]`
Understand TLSv1.2 vs TLSv1.3, how to generate self-signed certificates with `openssl`, and how NGINX terminates TLS.

---

## Phase 2 — Project Setup & Structure (~1 day)

### 2.1 Set up the VM `[mandatory]`
Create a Debian or Alpine virtual machine (VirtualBox or your school's system). Install Docker and Docker Compose inside it. Add your user to the `docker` group.

### 2.2 Create the directory structure `[mandatory]`

```
inception/
├── Makefile
└── srcs/
    ├── docker-compose.yml
    ├── .env
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        └── bonus/
            ├── redis/
            ├── ftp/
            ├── adminer/
            ├── static_site/
            └── extra_service/
```

### 2.3 Configure the `.env` file `[mandatory]`
Store ALL secrets here: DB name, DB user/pass, WP admin/user credentials, domain name (`yourlogin.42.fr`). Never hardcode passwords in Dockerfiles or `docker-compose.yml`.

Example `.env`:
```env
DOMAIN_NAME=yourlogin.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD=your_secure_password
MYSQL_ROOT_PASSWORD=your_root_password

WP_TITLE=Inception
WP_ADMIN_USER=yourlogin
WP_ADMIN_PASSWORD=your_admin_pass
WP_ADMIN_EMAIL=admin@example.com
WP_USER=guest
WP_USER_PASSWORD=guest_pass
WP_USER_EMAIL=guest@example.com

FTP_USER=yourlogin
FTP_PASSWORD=ftp_pass
```

### 2.4 Set up domain in `/etc/hosts` `[tip]`
Add `127.0.0.1 yourlogin.42.fr` to the VM's `/etc/hosts` so the domain resolves locally. Your Makefile can do this automatically.

### 2.5 Write the Makefile `[mandatory]`
Essential targets:

```makefile
all:     ## build and start everything
down:    ## stop and remove containers
clean:   ## stop + remove containers + volumes
fclean:  ## clean + remove images
re:      ## fclean + all
```

Use `docker compose -f srcs/docker-compose.yml` for all commands.

---

## Phase 3 — Mandatory Containers (one at a time!) (~5–7 days)

### 3.1 Container 1: MariaDB `[mandatory]`
- Base image: Debian or Alpine
- Install `mariadb-server`
- Write an `entrypoint.sh` that:
  - Initializes the DB with `mysql_install_db`
  - Creates the WordPress database
  - Creates the WP user with correct permissions
  - Sets the root password from env vars
- **No NGINX inside this container**
- Listen on port `3306`

### 3.2 Test MariaDB standalone `[tip]`
Run only the MariaDB container and connect to it from the host with a MySQL client. Verify the database and user were created correctly before moving on.

```bash
docker exec -it mariadb mysql -u wp_user -p
```

### 3.3 Container 2: WordPress + PHP-FPM `[mandatory]`
- Base image: Debian or Alpine
- Install `php-fpm` + `php-mysql`
- Use **WP-CLI** to:
  - Download WordPress (`wp core download`)
  - Create `wp-config.php` (`wp config create`)
  - Install WordPress (`wp core install`)
  - Create 2 users (1 admin, 1 regular)
- Listen on port `9000` (PHP-FPM socket)
- **No NGINX inside this container**

Key WP-CLI commands in your entrypoint:
```bash
wp core download --allow-root
wp config create --dbname=$MYSQL_DATABASE --dbuser=$MYSQL_USER --dbpass=$MYSQL_PASSWORD --dbhost=mariadb:3306 --allow-root
wp core install --url=$DOMAIN_NAME --title=$WP_TITLE --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASSWORD --admin_email=$WP_ADMIN_EMAIL --skip-email --allow-root
wp user create $WP_USER $WP_USER_EMAIL --role=author --user_pass=$WP_USER_PASSWORD --allow-root
```

### 3.4 Test WordPress + MariaDB together `[tip]`
Bring up only `mariadb` and `wordpress` services. Check that WP-CLI connects to the DB and PHP-FPM starts without errors.

### 3.5 Container 3: NGINX with TLS `[mandatory]`
- Base image: Debian or Alpine
- Install `nginx` + `openssl`
- Generate a self-signed certificate
- Configure `nginx.conf` to:
  - Listen on port `443` only
  - Use **TLSv1.2 or TLSv1.3 only** (no TLSv1.0/1.1)
  - `proxy_pass` PHP requests to `wordpress:9000` via FastCGI
  - Serve static files from the WordPress volume

Example NGINX config snippet:
```nginx
server {
    listen 443 ssl;
    server_name yourlogin.42.fr;

    ssl_certificate     /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    root /var/www/html;
    index index.php;

    location ~ \.php$ {
        fastcgi_pass wordpress:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

### 3.6 Bring all 3 containers together `[mandatory]`
Wire everything in `docker-compose.yml`:
- Define the `inception` Docker network
- Define two named volumes: `db_data` (MariaDB) and `wp_data` (WordPress files)
- Set correct `depends_on` (WordPress depends on MariaDB, NGINX depends on WordPress)
- Use `restart: on-failure` on all services
- Test `https://yourlogin.42.fr` in the browser

### 3.7 Verify the WordPress user rules `[mandatory]`
Confirm there are exactly 2 users in the `wp_users` table:
- 1 admin (username must NOT contain `admin`/`administrator`)
- 1 regular user

```bash
docker exec -it mariadb mysql -u root -p -e "SELECT user_login, user_email FROM wordpress.wp_users;"
```

---

## Phase 4 — Bonus Containers (~4–6 days)

> Bonus is only evaluated if the mandatory part is **perfect**. Complete Phase 3 fully before starting here.

### 4.1 Bonus 1: Redis Cache `[bonus]`
- Container running Redis server
- In the **WordPress** entrypoint, add to `wp-config.php`:
  ```bash
  sed -i "41 i define( 'WP_REDIS_HOST', 'redis' );\ndefine( 'WP_REDIS_PORT', '6379' );\n" wp-config.php
  ```
- Install and activate the Redis Cache plugin via WP-CLI:
  ```bash
  wp plugin install redis-cache --activate --allow-root
  ```
- Fix file permissions:
  ```bash
  chown -R www-data:www-data /var/www/html  # Debian
  # or
  chown -R nobody:nobody /var/www/html       # Alpine
  ```

### 4.2 Bonus 2: FTP Server (vsftpd) `[bonus]`
- Container with `vsftpd` pointing to the WordPress volume (`/var/www/html`)
- Configure passive mode ports: `30000–30009`
- Create FTP user from env vars
- Expose ports `21` and `30000-30009`
- Test with **FileZilla** connecting to `yourlogin.42.fr:21`

Key `vsftpd.conf` options:
```conf
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
pasv_enable=YES
pasv_min_port=30000
pasv_max_port=30009
local_root=/var/www/html
```

### 4.3 Bonus 3: Static Website `[bonus]`
- A simple site in HTML/CSS/JS (or Hugo, etc.) — **NOT PHP**
- Served by its own NGINX or another web server
- Accessible at a different port or path
- Good opportunity to build a personal portfolio page

### 4.4 Bonus 4: Adminer `[bonus]`
- Lightweight PHP database manager (single PHP file)
- Served behind NGINX at a port like `9001` or a sub-path
- Add a location block in `nginx.conf` to proxy Adminer
- Use it during defense to visually verify your MariaDB tables

### 4.5 Bonus 5: Extra Service of Your Choice `[bonus]`
Pick something you can justify and explain during the defense. Common choices:

| Service | Purpose |
|---|---|
| Netdata | System & container monitoring dashboard |
| MailHog | Email testing (catches outgoing WP emails) |
| cAdvisor | Container resource metrics |
| Portainer | Docker management UI |

---

## Phase 5 — Polish & Defense Prep (~2 days)

### 5.1 Security & secrets audit `[mandatory]`
- No passwords in Dockerfiles or `docker-compose.yml`
- All secrets come from `.env`
- `.env` is in `.gitignore` and NOT committed to git

### 5.2 Volumes persist on restart `[mandatory]`
Run `make re` and verify the WordPress data and DB are still there. Volumes must survive container recreation.

### 5.3 Clean build from scratch `[tip]`
Run `make fclean` then `make all` on a fresh VM. Everything must work without manual intervention.

### 5.4 Final forbidden-things checklist `[mandatory]`

- [ ] No `latest` image tags anywhere
- [ ] No passwords hardcoded in Dockerfiles
- [ ] No `network: host` or `--link`
- [ ] Each service has its own dedicated Dockerfile
- [ ] All images built from Alpine or Debian **only**
- [ ] No ready-made Docker Hub images used (except Alpine/Debian base)
- [ ] The `.env` file is not in the git repository

### 5.5 Prepare defense answers `[tip]`
Be ready to explain:

- What is a container vs a VM?
- Why not use ready-made images?
- What is PID 1 and why does it matter?
- How does TLS work in your setup?
- What does each container do?
- How are volumes and networks connected?
- What does each bonus service do and why did you choose it?

---

## Architecture Overview

```
                        Host machine
                        ┌─────────────────────────────────────┐
Browser ──HTTPS:443──►  │  NGINX container                    │
                        │    TLSv1.2/1.3                      │
                        │    ↓ FastCGI :9000                  │
                        │  WordPress + PHP-FPM container       │
                        │    ↓ MySQL :3306                    │
                        │  MariaDB container                   │
                        │                                      │
                        │  [bonus] Redis container             │
                        │  [bonus] FTP container  :21          │
                        │  [bonus] Adminer container           │
                        │  [bonus] Static site container       │
                        │  [bonus] Extra service               │
                        │                                      │
                        │  Volumes: db_data, wp_data           │
                        │  Network: inception (bridge)         │
                        └─────────────────────────────────────┘
```

---

## Useful Docker Commands

```bash
# Build and start everything
make all

# Stop and clean
make fclean

# Check running containers
docker ps

# View logs for a service
docker logs -f nginx

# Enter a container shell
docker exec -it wordpress bash
docker exec -it mariadb mysql -u root -p

# Check Redis is working
docker exec -it redis redis-cli ping   # should return PONG

# Inspect network
docker network inspect inception

# Check volume contents
docker volume inspect srcs_wp_data
```

---

*Good luck — the project is very doable if you go container by container!*
