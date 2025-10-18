# Build stage (kept minimal)
FROM alpine:3.20 AS build
WORKDIR /site
COPY site/ ./

# Runtime stage: Nginx serves the files
FROM nginx:alpine
COPY --from=build /site /usr/share/nginx/html
EXPOSE 80

