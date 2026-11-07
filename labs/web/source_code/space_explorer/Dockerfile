FROM golang:1.23 AS go-builder

WORKDIR /usr/src/go-getter

COPY go-app/go.mod go-app/go.sum ./
RUN go mod download
COPY go-app/*.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /docker-gs-ping

FROM python:3.9-slim

WORKDIR /usr/src/python-service

COPY python-service/app.py .

RUN pip install --no-cache-dir flask gunicorn

COPY --from=go-builder /docker-gs-ping /usr/local/bin/docker-gs-ping
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/docker-gs-ping

ENV FLAG="HTB{f4k3_fl4g_4_t3st1ng}"

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
