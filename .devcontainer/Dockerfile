# -------------------------
# Base image
# -------------------------
FROM mcr.microsoft.com/devcontainers/python:3.12

# Set working directory
WORKDIR /workspace

# Copy and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Optional: Install sqlite CLI for debugging
RUN apt-get update && apt-get install -y sqlite3 && apt-get clean

# Copy the rest of the code
COPY . .

# Expose port for OAuth redirect
EXPOSE 8080

# Default command
CMD ["bash"]
