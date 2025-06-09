FROM node:20-alpine AS css-builder

WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install

RUN apk add --no-cache curl && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        echo "Installing ARM64 version of lightningcss" && \
        npm install lightningcss-linux-arm64-musl; \
        npm install @tailwindcss/oxide-linux-arm64-musl; \
    elif [ "$ARCH" = "x86_64" ]; then \
        echo "Installing AMD64 version of lightningcss" && \
        npm install lightningcss-linux-x64-musl; \
        npm install @tailwindcss/oxide-linux-x64-musl; \
    else \
        echo "Unsupported architecture: $ARCH" && \
        exit 1; \
    fi

COPY . .
RUN npx tailwindcss -i ./src/input.css -o ./static/style.css

FROM golang:1.24.3 AS builder

WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
COPY --from=css-builder /app/static/style.css ./static/style.css
RUN CGO_ENABLED=0 GOOS=linux go build -o /tmp/build/app main.go

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /tmp/build/app /app

EXPOSE 8080

CMD ["/app"]
