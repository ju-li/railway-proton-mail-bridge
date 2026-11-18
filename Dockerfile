FROM golang:1.26-alpine AS build
RUN apk add --no-cache git
ARG HYDROXIDE_REF=master
RUN git clone https://codeberg.org/emersion/hydroxide.git /src && git -C /src checkout "$HYDROXIDE_REF"
WORKDIR /src
# Build the keep-alive helper inside the hydroxide module so it shares its go-imap version.
COPY keepalive/ /src/cmd/keepalive/
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /hydroxide ./cmd/hydroxide \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /hydroxide-keepalive ./cmd/keepalive

FROM alpine:3.22
RUN apk add --no-cache ca-certificates
COPY --from=build /hydroxide /hydroxide-keepalive /usr/local/bin/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV XDG_CONFIG_HOME=/data
EXPOSE 1025 1143 8080
ENTRYPOINT ["/entrypoint.sh"]
