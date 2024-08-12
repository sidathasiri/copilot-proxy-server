# copilot-proxy-server

## How to Setup

- Create a directory called `certs` and add the certificates to be used in each run
-  `docker build -t copilot-proxy-server .`
-  `docker run -d --rm -p 8080:8080 copilot-proxy-server`