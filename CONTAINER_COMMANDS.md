<<<<<<< HEAD
Copy-Item .env.example .env
notepad .env
npm run container:up
=======
## Initial setup

Generate a strong random password with `openssl rand -hex 32`.

Create `.env` from `.env.example` (`Copy-Item .env.example .env` in PowerShell or `cp .env.example .env` on Linux/macOS), then set `POSTGRES_PASSWORD` in `.env` to the generated value.

## Native development

Start Postgres in Docker:

```sh
docker compose up -d db
```

Run the backend and frontend locally:

```sh
npm run dev
```

Open http://localhost:5173. Postgres is published on `127.0.0.1:5432` for local development only.

## Run the full stack in Docker

```sh
docker compose up --build -d
>>>>>>> fb521ec56e31bfa71207d39fc9685373af0ba588
docker compose ps
```

Open http://localhost:8080.

<<<<<<< HEAD
Close all containers: docker compose down
=======
Stop the containers with `docker compose down`.
>>>>>>> fb521ec56e31bfa71207d39fc9685373af0ba588
