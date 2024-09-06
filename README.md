# Copilot Proxy Server

This project provides a proxy service implementation for GitHub Copilot. The proxy intercepts requests sent by developers (via their IDE) to GitHub servers, allowing you to:

- Track GitHub Copilot usage through telemetry requests.
- Inspect requests to enforce security practices.
- Monitor network usage.

Below is a high-level overview of the solution architecture:

![Proxy Solution Image](proxy_solution.png)

You can customize the proxy to intercept requests and execute specific actions using Python, as described below. The proxy server can be run as a Docker container.

> Read more about configuring network settings for GitHub Copilot [here](https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/configuring-network-settings-for-github-copilot?tool=vscode).

## Solution Overview

This proxy service is built using [mitmproxy](https://mitmproxy.org/). To use the proxy, first install the GitHub Copilot extension and configure it. By default, all Copilot-related requests are directed to GitHub servers. To use this proxy, update the `proxy_url` configuration to point to your proxy server, based on the IDE you are using. Refer to the guide [here](https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/configuring-network-settings-for-github-copilot?tool=vscode).

By default, this setup allows you to see the requests but not their actual payloads due to SSL encryption. To inspect the payloads of requests and responses, you need to use a custom certificate. When you install `mitmproxy`, it saves default certificates in the `~/.mitmproxy` folder, which are used for SSL interception.

![mitmproxy certificates](certs.png)

Make sure that the corresponding certificate (`mitmproxy-ca-cert.cer`/`mitmproxy-ca-cert.pem`) is installed on the developer's device to establish the proxy as a trusted entity.

- MAC: `sudo security add-trusted-cert -d -p ssl -p basic -k /Library/Keychains/System.keychain mitmproxy-ca-cert.pem`
- Windows: `certutil -addstore root mitmproxy-ca-cert.cer`

Further, to enhance the security, basic authentication has been enabled. So to connect with the proxy the correct username and password should be provided by the client.

## Sample Implementation

This repository provides the following sample features:

- Docker-based implementation.
- Terraform infrastructure code to deploy the proxy on AWS ECS with auto-scaling.
- Example implementation for intercepting requests and pushing accepted Copilot suggestions (`copilot/ghostText.accepted`) to an SQS queue.

## Prerequisites

- AWS account with necessary access for deployments (e.g., ECS, SQS).
- Terraform.
- Docker.

## Setup Instructions

1. **Certificate Setup**:

   - Create a `certs` directory and add the certificates to be used. You can install `mitmproxy` locally and copy the certificates from the `~/.mitmproxy` folder into this directory. This ensures that all proxy instances use the same certificates for SSL validation.

2. **Custom Logic Implementation**:

   - Customize the `main.py` file to implement your logic for intercepting Copilot events. The sample implementation pushes accepted suggestion events to an SQS queue. Update the `queue_url` to point to your desired SQS queue.

3. **Docker Image**:

   - Set the username and password placeholders (`<username>:<password>`) in the Dockerfile for the basic authentication. This is being used for additional security. Ensure same values are configured in the `proxy_url` in your client (ex. `http://{username}:{password}@localhost:8080`)
   - Build the Docker image with:
     ```bash
     docker build -t copilot-proxy-repo --platform linux/amd64 .
     ```
     (Modify the platform parameter as needed.)

4. **Running the Docker Image**:

   - Run the Docker container and expose port `8080` (the default port for mitmproxy). Set AWS credentials as environment variables to allow access to SQS for event publishing:
     ```bash
     docker run -it --rm -p 8080:8080 \
     -e AWS_ACCESS_KEY_ID=<your_access_key_id> \
     -e AWS_SECRET_ACCESS_KEY=<your_secret_access_key> \
     -e AWS_DEFAULT_REGION=us-east-1 \
     copilot-proxy-repo
     ```

5. **Deploying to AWS**:

   - Run `terraform apply -target=aws_ecr_repository.copilot_proxy_repo` to create the ECR repository first.
   - Push the Docker image to ECR (follow ECR guidelines for tagging and pushing images).
   - Run `terraform apply` to deploy the remaining resources.

6. **Using the Proxy**:
   - Access the proxy server via the domain of the created Network Load Balancer (NLB) instance.
   - Update the `proxy_url` in your IDE settings to route requests through the proxy.

## Additional Resources

- For more information on configuring GitHub Copilot network settings, refer to the official documentation [here](https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/configuring-network-settings-for-github-copilot?tool=vscode).
- Read more on the official mitmproxy documentation [here](https://docs.mitmproxy.org/stable/) 
