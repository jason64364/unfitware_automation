# Build the image
docker build -t ubuntu-dev:latest .

# Run it (bind localhost for safety; set your own password)
docker run -d --name devdesk \
  -p 127.0.0.1:8080:8080 \
  -e PASSWORD='Your$trongP@ss' \
  -e USERNAME=dev \
  -v $PWD:/home/dev/workspace \
  -v code_data:/home/dev/.local/share/code-server \
  ubuntu-dev:latest
