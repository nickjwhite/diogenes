# Build Docker container for morphology server
# Run with --init flag
FROM perl:5.20
WORKDIR /app
COPY server /app/server
COPY dependencies /app/dependencies
EXPOSE 8990
CMD [ "perl", "/app/server/morph-server.pl" ]
