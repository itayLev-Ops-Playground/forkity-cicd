# Run Forkity on a New Ubuntu 24.04 VM

This guide walks through deploying Forkity on a clean Ubuntu 24.04 LTS virtual machine. Follow the sections in order. Commands are entered in the VM terminal after connecting over SSH.

Forkity runs in three Docker containers: the website, the API, and PostgreSQL. You do not need to install Node.js or PostgreSQL on the VM itself. You do need Docker Engine and Docker Compose v2.

## Before you start

You need:

- An Ubuntu 24.04 LTS VM with an internet connection.
- A way to connect to it, usually SSH.
- The Git URL of this repository.
- Permission to change the VM firewall or cloud security group.

Connect using the SSH command from your VM provider. It commonly looks like this:

```bash
ssh YOUR_USERNAME@YOUR_VM_IP
```

Replace the capitalized example values with your own. `sudo` runs an administrator command; Ubuntu may ask for your Linux account password.

## 1. Install Docker Engine and Compose

Run these commands in the VM terminal. They add Docker's official Ubuntu package repository, install Docker Engine and Compose v2, then start Docker automatically at boot.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Confirm Docker and Compose are installed:

```bash
sudo docker --version
sudo docker compose version
sudo systemctl is-active docker
```

Each command should print a version or `active`. Use `sudo` before Docker commands in this guide. This avoids granting your Linux account administrator-level access through the Docker group.

See Docker's [official Ubuntu installation guide](https://docs.docker.com/engine/install/ubuntu/) for more information.

## 2. Download the application

Install Git, then clone the repository. Replace `YOUR_REPOSITORY_URL` with the repository's clone URL. For a private repository, make sure this VM has authorized Git credentials or an SSH key.

```bash
sudo apt-get install -y git
git clone YOUR_REPOSITORY_URL forkity
cd forkity
```

`cd forkity` moves into the project directory. Run all remaining project commands from this directory.

## 3. Configure the database password

Create the environment configuration file from the example:

```bash
cp .env.example .env
```

Generate a random password:

```bash
openssl rand -hex 32
```

Copy the generated text and open the environment file:

```bash
nano .env
```

Change `POSTGRES_PASSWORD` to the generated password. The file should look like this, with your password in place of the example text:

```dotenv
POSTGRES_DB=forkity
POSTGRES_USER=forkity
POSTGRES_PASSWORD=paste_your_generated_password_here
FORKITY_PORT=8080
```

Keep the other values as shown unless you want a different website port. Save in nano with **Ctrl+O**, press **Enter**, then exit with **Ctrl+X**.

Restrict access to the file and check the non-secret settings:

```bash
chmod 600 .env
grep -E '^(POSTGRES_DB|POSTGRES_USER|FORKITY_PORT)=' .env
```

Do not post or commit `.env`; it contains your database password. The repository ignores this file.

## 4. Build and start Forkity

Run:

```bash
sudo docker compose up --build -d
```

The first build downloads base images and installs application dependencies inside the images. It can take several minutes. The `-d` option leaves the containers running in the background.

Check container status:

```bash
sudo docker compose ps
```

Wait until the database, backend, and frontend show as running and healthy. If a service is still starting, wait a little and run the command again.

## 5. Open the website

The default website port is `8080`. Allow inbound TCP traffic on that port in your VM provider's firewall or security group. If Ubuntu's UFW firewall is enabled, allow SSH and the website port before enabling or changing firewall rules, so you do not lock yourself out:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 8080/tcp
sudo ufw status
```

If UFW is inactive and you want to enable it, do so only after allowing SSH:

```bash
sudo ufw enable
```

Open this address in your browser, replacing `YOUR_VM_PUBLIC_IP` with the VM's public IP:

```text
http://YOUR_VM_PUBLIC_IP:8080
```

If you changed `FORKITY_PORT` in `.env`, use that port instead. For example, with `FORKITY_PORT=8081`, allow port `8081` through both firewalls and open `http://YOUR_VM_PUBLIC_IP:8081`.

This setup serves HTTP. To use a domain name and HTTPS, configure a TLS reverse proxy separately.

## Check the application and view logs

Check the API health endpoint from the VM:

```bash
curl -i http://localhost:8080/api/health
```

An HTTP success response means the API is responding. You can also load the website in your browser.

If something does not start, view recent logs for all services:

```bash
sudo docker compose logs --tail=100
```

Follow live logs while troubleshooting; press **Ctrl+C** to stop following logs (the containers keep running):

```bash
sudo docker compose logs -f
```

Check whether Docker is running:

```bash
sudo systemctl status docker --no-pager
```

## Common problems

### Docker says permission denied

Use `sudo` before Docker commands, for example `sudo docker compose ps`.

### Compose says `Set POSTGRES_PASSWORD in .env`

Make sure you ran `cp .env.example .env` and replaced the example password in `.env`. Run `sudo docker compose up --build -d` again from the project directory.

### The website cannot be reached from my computer

Confirm the containers are healthy with `sudo docker compose ps`. Check that port `8080` (or your configured `FORKITY_PORT`) is allowed in both the VM provider's firewall/security group and, if active, UFW. Use the VM's public IP, not `localhost`, in your computer's browser.

### The build reports a Docker Hub 502 error

This is usually a temporary registry or network response. Retry the build:

```bash
sudo docker compose up --build -d
```

If it continues, check that the VM has internet access and retry later.

## Stop, restart, or update Forkity

Stop the containers while keeping the database:

```bash
sudo docker compose down
```

Start them again:

```bash
sudo docker compose up -d
```

To get the latest committed version and rebuild (run from the `forkity` directory):

```bash
git pull
sudo docker compose up --build -d
```

## Database data and backups

PostgreSQL data is kept in a Docker named volume. It survives normal container restarts and `sudo docker compose down`. **Do not run `sudo docker compose down --volumes` or `sudo docker compose down -v` unless you intend to delete the database data.**

If the repository contains `backend/data/forkity.db`, the backend imports that legacy SQLite data into an empty PostgreSQL database the first time it starts. The import is skipped after Forkity data exists in PostgreSQL.

For a real deployment, make regular backups of the PostgreSQL data and store the backups somewhere outside this VM.
