FROM mitmproxy/mitmproxy

# Copy certificates into the Docker image
COPY certs /home/mitmproxy/.mitmproxy

# Copy your mitmproxy script if you have one
COPY main.py /main.py

# Set working directory
WORKDIR /

# Run mitmproxy with the specified configurations
CMD ["mitmproxy", "--set", "block_global=false", "--listen-port", "8080", "-s", "/main.py"]