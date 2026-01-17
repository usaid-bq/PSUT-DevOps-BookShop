# PSUT DevOps Course – Graduation Project

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
* Kubernetes (local tooling)
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
* **Kubernetes (Single Node on EC2):** Runs the production version of the application using Release images.
* **NGINX:** Installed on the EC2 instance as a reverse proxy with two server blocks:
    * **Port 80:** Routes traffic to the Kubernetes-managed production application.
    * **Port 8080:** Routes traffic to the Docker-managed snapshot application.

#### Security Groups
One Security Group is attached to the EC2 instance. Inbound traffic is explicitly restricted to:
* Ports required by NGINX (**80** and **8080**)
* All other inbound traffic is denied.

## CI/CD Pipeline
The CI/CD pipeline automates application packaging, image storage, and deployment based on Git branch activity.

### Application Packaging
* **Dockerfile:** Located in the `book-shop` directory (the Django project root).
* **Image Types:**
    * **Snapshot Images:** Represent development or intermediate states.
    * **Release Images:** Represent production-ready, versioned states.

### Image Versioning and Storage
All images are stored in a public Amazon ECR repository. Versioning is based on:
1.  Application version (defined as `$VERSION` in `pyproject.toml`)
2.  Git commit SHA
3.  Image type (Snapshot or Release)

### Pipeline Triggers and Behavior

#### 1. Push to `dev` Branch (Development Workflow)
* A new Docker image is built and tagged as: `$VERSION-SNAPSHOT-<GIT_SHA>`.
* The image is pushed to the public ECR repository.
* The EC2 instance pulls the new Snapshot image.
* The running Docker container on EC2 is restarted.
* Traffic to port **8080** is updated automatically.

#### 2. Push to `main` Branch (Release Workflow)
* A new GitHub Release and Git tag are created using `$VERSION`.
* The corresponding Snapshot image is promoted to a **Release** image in ECR.
* The Release image is pulled by the EC2 instance.
* The Kubernetes workload is updated via a rolling restart or update.
* The production application (exposed on port **80**) runs the new Release image.

## Notes
* Snapshot and Release images share the same base image and configuration, differing only in tagging and deployment target.
* Docker is intentionally used for development/testing workloads, while Kubernetes is reserved for production to demonstrate both paradigms.
* Infrastructure provisioning and configuration are automated using Terraform.

### Application Source
The Django application utilized in this project was provided by **Eng. Ayat Alkayed** (Course Instructor) to serve as a standardized functional baseline.

For further details regarding the application's architecture and best practices, refer to the original documentation:
* [Django 4.0.4 Best Practices Tutorial : Part 1](https://ayat.hashnode.dev/django-404-best-practices-tutorial-part-1)