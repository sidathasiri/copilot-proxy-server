# copilot-proxy-server

## How to Setup

- Create a directory called `certs` and add the certificates to be used in each run
- Update the `queue_url` in `main.py`
- Build the docker image with `docker build -t copilot-proxy-server .`
- Run the docker image. Ensure to set the AWS credentials as env variables

```
docker run -it --rm -p 8080:8080 \
-e AWS_ACCESS_KEY_ID=<key_id> \
-e AWS_SECRET_ACCESS_KEY=<secret_key> \
-e AWS_DEFAULT_REGION=us-east-1 \
copilot-proxy-server
```