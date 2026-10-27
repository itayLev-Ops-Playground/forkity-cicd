# Jenkins host setup (Ubuntu 24.04)

The Jenkins pipeline runs on the host and needs Java 21, Node.js 22, npm, Git,
Docker Engine, and the Docker Compose v2 plugin. Run these scripts from the
repository root on a clean Ubuntu 24.04 Jenkins host:

```bash
sudo bash scripts/prepare-jenkins-ubuntu24.sh
sudo -u jenkins bash scripts/verify-jenkins-ubuntu24.sh
```

The preparation script installs Jenkins LTS and the pipeline dependencies,
enables Docker and Jenkins at boot, and grants the `jenkins` service account
Docker access. Docker group access is effectively root access, so only trusted
Jenkins jobs and administrators should have access to this controller/agent.

After setup, open `http://<server-ip>:8080`, finish Jenkins' first-run setup,
and create a Pipeline job configured to load the `Jenkinsfile` from this Git
repository. Allow inbound port 8080 only from trusted networks. Builds need
outbound HTTPS access to the package repositories and Docker Hub.

The pipeline runs the verification script before each build, then executes
`npm ci` to install the repository's locked npm dependencies. Run the
preparation script once as an administrator; it should not run as part of a
build because it installs system packages and changes host services/users.
