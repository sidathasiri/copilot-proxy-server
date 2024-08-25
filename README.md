# copilot-proxy-server

## How to Setup

- Create a directory called `certs` and add the certificates to be used in each run
- Update the `queue_url` in `main.py`
- Set the username and password placeholders (`<username>:<password>`) in the Dockerfile for the basic authentication. Ensure same values are configured in your client
- Build the docker image with `docker build -t copilot-proxy-server --platform linux/amd64 .`
- Run the docker image. Ensure to set the AWS credentials as env variables

```
docker run -it --rm -p 8080:8080 \
-e AWS_ACCESS_KEY_ID=<key_id> \
-e AWS_SECRET_ACCESS_KEY=<secret_key> \
-e AWS_DEFAULT_REGION=us-east-1 \
copilot-proxy-server
```

- Run `terraform apply -target=aws_ecr_repository.copilot_proxy_repo` to create the ECR repo
- Push the image to the repository
- Run `terraform apply` to create resources
