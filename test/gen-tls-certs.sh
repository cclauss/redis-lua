#!/bin/sh -e
# Generate a throwaway CA and server certificate for running the test
# suite against a TLS-enabled Redis server:
#
#   ./test/gen-tls-certs.sh tls
#   redis-server --port 0 --tls-port 6390 \
#       --tls-cert-file tls/server.crt --tls-key-file tls/server.key \
#       --tls-ca-cert-file tls/ca.crt --tls-auth-clients no
#   REDIS_TLS_PORT=6390 REDIS_TLS_CAFILE=tls/ca.crt busted

dir="${1:-tls}"
mkdir -p "$dir"

openssl genrsa -out "$dir/ca.key" 2048
openssl req -x509 -new -nodes -key "$dir/ca.key" -sha256 -days 3650 \
    -subj '/CN=redis-lua test CA' -out "$dir/ca.crt"

openssl genrsa -out "$dir/server.key" 2048
openssl req -new -key "$dir/server.key" -subj '/CN=127.0.0.1' \
    -out "$dir/server.csr"
openssl x509 -req -in "$dir/server.csr" -CA "$dir/ca.crt" \
    -CAkey "$dir/ca.key" -CAcreateserial -days 3650 -sha256 \
    -out "$dir/server.crt"

# the test server may run as a different user (e.g. in a container)
chmod 644 "$dir"/*.key "$dir"/*.crt
