# PSUT DevOps Course – Graduation Project

**[!] Disclamer [!]***
The IaC and the CI/CD pipeline have not yet been actually tested.
The current implimentation is purely theoretical.
I have not had the time to properly test and debug yet since the project coincided with my preperation for Final Exams.
I plan on going back and going over the project again when I'm done with exams on the 25th In Sha' Allah.

## Overview
The primary objective of this project is to demonstrate a complete DevOps workflow, including:

* **Application containerization**
* **Infrastructure provisioning on AWS**
* **Image management using Amazon ECR**
* **CI/CD automation**
* **Deployment using both Docker and Kubernetes**

The project separates development (**Snapshot**) and production (**Release**) deployment paths while using a single AWS EC2 instance as the runtime environment.

## Architecture Overview
The solution is composed of two main environments:
1.  **Local Development Environment**
2.  **Production Environment on AWS**

Both environments rely on containerization, with CI/CD used to automate image creation, promotion, and deployment.

## Infrastructure

### Development Environment (Local)
The development environment runs on the developer’s local machine (Ubuntu).
**Installed tools:**
* Docker
* Terraform
* AWS CLI
* MicroK8s (local tooling)
* Git (configured with a personal GitHub account)

In this environment, the Django application is containerized using Docker for local development and testing. No cloud resources are required to validate initial application behavior.

### Production Environment (AWS)

#### Networking
* **One AWS VPC**
* **One public subnet** within the VPC
* **Internet access** enabled for inbound traffic

#### Compute and Services
* **Amazon EC2:** Ubuntu-based instance with a 30 GB EBS volume located in the public subnet.
* **Amazon Elastic Container Registry (ECR) – Public:** Stores both Snapshot and Release application images.
* **Docker:** Runs the development/testing version of the application using Snapshot images.
* **MicroK8s (Single Node on EC2):** Runs the production version of the application using Release images.
* **NGINX:** Installed on the EC2 instance as a reverse proxy with two server blocks:
    * **Port 80:** Routes traffic to the Kubernetes-managed production application.
    * **Port 8080:** Routes traffic to the Docker-managed snapshot application.

#### Security Groups
One Security Group is attached to the EC2 instance. Inbound traffic is explicitly restricted to:
* Ports required by NGINX (**80** and **8080**)
* All other inbound traffic is denied.

## CI/CD Pipeline and Deployment Strategy

The project implements a promotion-based CI/CD pipeline using GitHub Actions, Amazon ECR (Public), Docker, and MicroK8s. This ensures that the exact code tested in development is the one that reaches production without being rebuilt.

### Application Packaging

- **Containerization**: The Django application is packaged using a Dockerfile located in the book-shop directory.
- **Immutable Artifacts**: Once an image is built, it is never altered. It is moved through environments by re-tagging rather than re-building to ensure artifact consistency.

### Image Versioning Logic

All images are stored in a public Amazon ECR repository using a structured tagging scheme:
1. **Snapshot Tags**: vX.Y.Z-SNAPSHOT-<7-char-sha> (Used for Development and Testing)
2. **Release Tags**: vX.Y.Z (Used for Production)

### Pipeline Workflows

#### 1. Development Workflow (Continuous Deployment)

**Trigger**: Any push to the dev branch.

- **Build**: Extracts the version from pyproject.toml and the Git SHA to build a unique Snapshot image.
- **Registry**: Pushes the Snapshot to Amazon ECR.
- **Deploy**: Connects via SSH to the EC2 instance and restarts the Docker container.
- **Access**: The Dev environment is immediately updated and accessible on Port 8080. Nginx proxies this traffic to the internal host port 4000.

#### 2. Production Workflow (Promotion and Release)

**Trigger**: A push or merge to the main branch.

- **Promotion**: The pipeline identifies the existing Snapshot image in ECR associated with the current commit and re-tags it with the official version (e.g., v1.2.0). No rebuilding occurs.
- **Release**: Automatically creates a GitHub Release with generated changelogs and an official Git tag using the softprops/action-gh-release action.
- **Orchestration**: Connects via SSH to the EC2 instance and instructs MicroK8s to perform a rolling update.
- **Rollout**: Kubernetes applies the updated k8s/app-prod.yaml manifest. The deployment image is updated to the new release tag, and MicroK8s ensures zero-downtime as traffic on Port 80 shifts to the new version.

### Network and Environment Mapping

The EC2 instance separates environments by port using Nginx as a reverse proxy:

- **Development Environment**
  - Registry Tag: SNAPSHOT
  - Infrastructure: Docker
  - Host Port: 4000
  - Nginx Entry: Port 8080

- **Production Environment**
  - Registry Tag: vX.Y.Z
  - Infrastructure: MicroK8s
  - Host Port: 30001 (NodePort)
  - Nginx Entry: Port 80

### Design Guarantees

- **Environment Parity**: Dev and Prod run the identical image artifact.
- **Traceability**: Every production release is linked to a specific GitHub Release and Git commit SHA.
- **Safety**: Kubernetes health checks ensure the new version is healthy before shutting down the old pods.

## Notes
* Docker is intentionally used for development/testing workloads, while Kubernetes is reserved for production to demonstrate both paradigms.
* Infrastructure provisioning and configuration are automated using Terraform.

### Application Source
The Django application utilized in this project was provided by **Eng. Ayat Alkayed** (Course Instructor) to serve as a standardized functional baseline.

For further details regarding the application's architecture and best practices, refer to the original documentation:
* [Django 4.0.4 Best Practices Tutorial : Part 1](https://ayat.hashnode.dev/django-404-best-practices-tutorial-part-1)