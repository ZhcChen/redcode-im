FROM golang:1.25-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /out/external-mock ./cmd/external-mock

FROM alpine:3.22

RUN apk add --no-cache ca-certificates
COPY --from=builder /out/external-mock /usr/local/bin/external-mock

EXPOSE 19080
CMD ["external-mock"]
