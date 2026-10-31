# Build stage
FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/bin/server ./cmd/server

# Runtime stage
FROM alpine:3.20
RUN apk --no-cache add ca-certificates tzdata
ENV TZ=America/Bogota
WORKDIR /app
COPY --from=builder /app/bin/server .
COPY --from=builder /app/migrations ./migrations

EXPOSE 4000

CMD ["./server"]
