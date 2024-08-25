FROM mitmproxy/mitmproxy

# Copy certificates into the Docker image
COPY certs /home/mitmproxy/.mitmproxy

# Copy your mitmproxy script if you have one
COPY main.py /main.py

# Install boto3 using pip
RUN pip install boto3

# Set working directory
WORKDIR /

# Run mitmdump with the specified configurations
CMD ["mitmdump", "--set", "block_global=false", "--proxyauth", "<username>:<password>", "--listen-port", "8080", "-s", "/main.py"]