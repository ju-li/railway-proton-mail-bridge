FROM golang:1.26-alpine AS build
RUN apk add --no-cache git
ARG HYDROXIDE_REF=master
RUN git clone https://codeberg.org/emersion/hydroxide.git /src && git -C /src checkout "$HYDROXIDE_REF"
WORKDIR /src
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /hydroxide ./cmd/hydroxide

FROM alpine:3.22
RUN apk add --no-cache ca-certificates
COPY --from=build /hydroxide /usr/local/bin/hydroxide
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV XDG_CONFIG_HOME=/data
EXPOSE 1025 1143 8080
ENTRYPOINT ["/entrypoint.sh"]
