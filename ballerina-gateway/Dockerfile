# Dockerfile for Ballerina API Gateway

# Use official Ballerina runtime image
FROM ballerina/ballerina:2201.8.0

# Set working directory
WORKDIR /app

# Copy Ballerina project files
COPY Ballerina.toml .
COPY Dependencies.toml .
COPY main.bal .
COPY modules/ modules/

# Build the Ballerina application
RUN bal build

# Expose the application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["bal", "run"]