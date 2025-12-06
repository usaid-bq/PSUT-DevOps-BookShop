#!/bin/bash
set -e

APP_IMAGE_NAME="psut-devops-bookshop-image"
APP_CONTAINER_NAME="psut-devops-bookshop-container"

# Execute SQL Commands inside the container via docker exec
echo "Building App Image"
docker build --tag $APP_IMAGE_NAME ./book-shop/
echo "Image was successfully build: ${APP_IMAGE_NAME}"

echo "Starting Container"
docker run --name $APP_CONTAINER_NAME -p 80:80 -d $APP_IMAGE_NAME
echo "Container is running: ${APP_CONTAINER_NAME}"
