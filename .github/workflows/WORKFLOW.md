# CI/CD Workflow Explenation

## Dev Workflow
### he Trigger
Event: Monitor the repository for a push.

Filter: Only act if the push happens on the dev branch.

### Environment Setup (The Runner)
Spin up: Start a fresh Ubuntu virtual machine provided by GitHub.

Checkout: Download a copy of your code onto this machine.

Tools: Ensure Docker and AWS-CLI are ready to use.

### Extract Metadata (The Versioning)
Read Version: Open pyproject.toml, find the version = "X.Y.Z" line, and grab the numbers.

Get SHA: Grab the unique 7-character "Short SHA" of the current commit.

Combine: Create a variable called IMAGE_TAG that looks like X.Y.Z-SNAPSHOT-<SHA> (e.g., 1.2.0-SNAPSHOT-7d2a1b).

### AWS Authentication
Log in: Use your AWS_ACCESS_KEY and AWS_SECRET_KEY to authenticate the runner.

ECR Access: Specifically log into your Amazon ECR Public registry so you have permission to push images.

### Build and Push (The Packaging)
Docker Build: Run the command to create the image based on your Dockerfile.

Apply Tag: Label that build with your IMAGE_TAG.

Push: Upload that specific tagged image to your ECR repository.

### Remote Deployment (The "Handshake")
Connect: Use an SSH Action to open a secure tunnel into your EC2 instance using the EC2_SSH_KEY.

Commands to run on the EC2:

Auth: Log the EC2 instance into ECR (so it can pull the image).

Pull: Download the brand-new IMAGE_TAG from ECR.

Stop/Clean: Stop the old "dev-app" container if it’s running and delete it.

Run: Start a new container:

Map Port 8080 on the EC2 to Port 8000 (or whatever Django uses) inside the container.

Name it dev-app for easy tracking.

Cleanup: Remove old, unused Docker images to save that 30GB disk space.

## Prod Workflow

### The Trigger
Event: Monitor the repository for a push.

Filter: Only act if the push happens on the main branch.

Alternative: You could trigger this when a Pull Request is merged from dev to main.

### Environment Setup
Runner: Start a fresh Ubuntu virtual machine.

Checkout: Download the code.

Tools: AWS-CLI and GitHub CLI (gh) are required.

### Metadata Extraction (Identification)
Read Version: Extract the version (e.g., 1.2.0) from pyproject.toml.

Find Snapshot: Determine the tag of the image currently in ECR that corresponds to this commit (e.g., 1.2.0-SNAPSHOT-7d2a1b).

### GitHub Release Creation (The Official Stamp)
Action: Use the softprops/action-gh-release or gh CLI.

Inputs: * Tag: (The version we read from the file).

Notes: Automatically generate a list of all commits/PRs merged since the last release.

Result: A new Git Tag and a "Release" page appear in your GitHub repository.

### ECR Promotion (The Re-Tagging)
Logic: "Tell AWS: Take the image currently labeled SNAPSHOT and give it a second label like vX.Y.Z (e.g., v1.2.0).

Benefit: This ensures the production code is 100% identical to what you just tested in dev. No new layers are uploaded; it’s just a pointer change in ECR.

### Kubernetes Deployment (The Live Switch)
Connect: Use an SSH Action to log into the EC2 instance.

Commands to run on the EC2 (using MicroK8s):

Apply the Manifest: It runs microk8s kubectl apply -f k8s/app-prod.yaml. This ensures that if you changed the number of replicas or memory limits, Kubernetes updates those immediately.

Set the New Image: It runs the set image command using the specific tag that triggered the workflow.
microk8s kubectl set image deployment/django-app django-container=${{ env.ECR_REGISTRY }}/book-shop:${{ github.ref_name }}

Rollout Status: It monitors the transition. Kubernetes starts the "v1.2.0" pods and only shuts down the old ones once the new ones are healthy.