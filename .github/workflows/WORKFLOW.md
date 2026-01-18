# CI/CD Workflow Explanation

This document describes the **Dev** and **Prod** CI/CD workflows used to build, promote, and deploy the application using **GitHub Actions**, **Public Amazon ECR**, **Docker**, and **MicroK8s** on an EC2 instance provisioned via Terraform.

The workflows follow a **promotion-based model**:
- Dev builds immutable SNAPSHOT images
- Prod promotes an already-tested image to a versioned release
- No rebuilding occurs in production

---

## Dev Workflow (Development / Snapshot)

### 1. Trigger
Event: Monitor the repository for a push  
Filter: Only act if the push happens on the `dev` branch

---

### 2. Environment Setup (GitHub Actions Runner)
Runner:
- A fresh Ubuntu virtual machine provided by GitHub

Steps:
- Check out the repository code
- Ensure Docker is available
- Install or ensure AWS CLI is available (used only for pushing images)

---

### 3. Metadata Extraction (Versioning)
- Read the application version from `pyproject.toml` (e.g., `1.2.0`)
- Extract the short Git commit SHA (7 characters)
- Construct an immutable snapshot image tag:

IMAGE_TAG = `X.Y.Z-SNAPSHOT-<short-sha>`  
Example: `1.2.0-SNAPSHOT-7d2a1b`

This tag uniquely identifies the code and build.

---

### 4. AWS Authentication (Push Only)
- Authenticate the GitHub Actions runner using:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- Log Docker into **Amazon Public ECR** (us-east-1)

Note:
- Authentication is required only for **pushing**
- Pulling from Public ECR does not require credentials

---

### 5. Build and Push (Packaging)
- Build the Docker image from the Dockerfile
- Tag the image using the SNAPSHOT tag
- Push the image to the Public ECR repository

Result:
- A new immutable SNAPSHOT image is available in Public ECR

---

### 6. Remote Deployment (Dev Runtime on EC2)
Connection:
- Use an SSH-based GitHub Action to connect to the EC2 instance using `EC2_SSH_KEY`

Actions on EC2:
- Pull the SNAPSHOT image from Public ECR (no AWS auth required)
- Stop and remove the existing `dev-app` container if it exists
- Run a new container:
  - Map host port `4000` → container port `8000`
  - Name the container `dev-app`
- Clean up unused Docker images to conserve disk space

Traffic Flow:
- Nginx listens on port `8080`
- Nginx proxies traffic to `localhost:4000`
- The Docker container listens on `8000`

---

## Prod Workflow (Release / Promotion)

### 1. Trigger
Event: Monitor the repository for changes  
Primary Trigger: Push to the `main` branch  
Alternative Trigger: Merge of a Pull Request from `dev` to `main`

---

### 2. Environment Setup (GitHub Actions Runner)
Runner:
- A fresh Ubuntu virtual machine provided by GitHub

Steps:
- Check out the repository code
- Ensure Docker and AWS CLI are available
- GitHub CLI (`gh`) or a release action is used to create releases

---

### 3. Metadata Extraction (Release Identification)
- Read the release version from `pyproject.toml` (e.g., `1.2.0`)
- Retrieve the SNAPSHOT image tag that was built and tested in the Dev workflow

Important:
- The SNAPSHOT tag is treated as the **single source of truth**
- It must be passed from Dev to Prod (via release notes, artifacts, or workflow outputs)
- The Prod workflow does not attempt to infer the SNAPSHOT tag automatically

---

### 4. GitHub Release Creation (Official Versioning)
- Create a GitHub Release for version `vX.Y.Z`
- Generate release notes automatically (commits / PRs since last release)
- Create an annotated Git tag matching the release version

This step marks the code as officially promoted to production.

---

### 5. Image Promotion in Public ECR (Re-Tagging)
Because Public ECR does not support server-side retagging:

- Pull the SNAPSHOT image from Public ECR
- Tag it with the release version (e.g., `v1.2.0`)
- Push the new tag back to Public ECR

Notes:
- No new layers are built
- The production image is byte-for-byte identical to the tested SNAPSHOT image

---

### 6. Kubernetes Deployment (Production Rollout)
Connection:
- Use SSH to connect to the EC2 instance

Execution:
- All Kubernetes commands are executed with elevated permissions:
  - `sudo microk8s kubectl ...`

Steps on EC2:
- Apply the Kubernetes manifests:
  - Ensures replicas, resources, and config are up to date
- Update the deployment image to the new release tag:
  - `book-shop:vX.Y.Z`
- Monitor rollout status:
  - New pods must become healthy before old pods are terminated

Result:
- Zero-downtime deployment
- Production runs the exact image promoted from Dev

---

## Key Design Guarantees
- Dev and Prod use the same container artifacts
- No rebuilding occurs in production
- Public ECR removes the need for AWS credentials on EC2
- Kubernetes handles rollout safety and health checks
- Image tags are immutable and traceable back to Git commits
