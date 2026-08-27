# Multi-stage build
# Stage 1: Builder
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY main.go .
COPY main_test.go .

# Build a statically linked binary with version injection via ldflags
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-X main.version=${VERSION}" \
    -o app .

# Stage 2: Runtime (minimal base image)
FROM scratch

COPY --from=builder /app/app /app

EXPOSE 8080

ENTRYPOINT ["/app"]
