#!/bin/sh
# Netcat wrapper to encrypt traffic with openssl

# Display usage
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo 'Netcat wrapper to encrypt traffic with openssl

Usage:
  ./ncenc.sh <nc arguments...>

Example:
  ./ncenc.sh -lvnp 4242 # Listen on port 4242
  ./ncenc.sh 127.0.0.1 4242 # Connect to 4242 on localhost

  See more with `./ncenc.sh -h`'
  exit 1
fi

# Check if tools are installed and return them absolute path
check_tool() {
  tool_path=$(which $1)
  if ! [ -x "$tool_path" ]; then
    echo "Error: $1 is missing, please install it." >&2
    return 1
  fi
  echo $tool_path
}

OPENSSL=$(check_tool openssl) || exit $?
NC=$(check_tool nc) || exit $?
BASE64=$(check_tool base64) || exit $?

# Retrieve arguments
NC_ARGS=""
SOCKET_TYPE="client"
IS_VERBOSE=false
for arg in "$@"; do
  # Check if nc is running as a server or client
  if [ "$arg" = "-l" ] || [ "$arg" = "--listen" ] || echo "$arg" | grep -Eq '^\-.*l.*$'; then
    SOCKET_TYPE="server"
  fi
  # Check if nc is verbose
  if [ "$arg" = "-v" ] || [ "$arg" = "--verbose" ] || echo "$arg" | grep -Eq '^\-.*v.*$'; then
    IS_VERBOSE=true
  fi
  NC_ARGS="$NC_ARGS $arg"
done

# Echo verbose  only if verbose mode is enabled
verbose_echo() {
  if $IS_VERBOSE; then
    echo "$@" >&2
  fi
}

# Create temporary directory to store encryption keys
KEYS_PATH="$(mktemp -d)"
trap 'rm -rf -- "$KEYS_PATH"' EXIT

# Generate key pair with openssl
verbose_echo "Generating key pair..."
MY_KEY_PATH="$KEYS_PATH/mykey.pem"
$OPENSSL genrsa 2048 >"$MY_KEY_PATH"
MY_PUBLIC_KEY=$($OPENSSL pkey -in "$MY_KEY_PATH" -outform pem -pubout)

SKYF0L_PUBLIC_KEY_PATH="$KEYS_PATH/skyf0lpubkey.pem"

# Nc loop
(
  ## Wait for nc start
  sleep 0.2

  ## Send server public key
  if [ "$SOCKET_TYPE" = "server" ]; then
    verbose_echo "Send server public key..."
    echo "$MY_PUBLIC_KEY"
  fi

  ## Wait until other public key is received
  verbose_echo "Wait for other public key..."
  while [ ! -f "$SKYF0L_PUBLIC_KEY_PATH" ]; do
    sleep .2
  done

  ## Check if received public key is valid, otherwise exit
  $OPENSSL pkey -inform PEM -pubin -in "$SKYF0L_PUBLIC_KEY_PATH" -noout
  if [ $? -ne 0 ]; then
    echo "Error: Invalid client public key." >&2
    exit 1
  fi

  ## Send client public key
  if [ "$SOCKET_TYPE" = "client" ]; then
    verbose_echo "Send client public key..."
    echo "$MY_PUBLIC_KEY"
  fi

  verbose_echo "=========================="

  ## Read from stdin loop
  while IFS= read -r IN; do
    echo -n "$IN" | $OPENSSL pkeyutl -encrypt -pubin -inkey "$SKYF0L_PUBLIC_KEY_PATH" | $BASE64 -w 0
    echo
  done
) |
  (
    ## Run nc server
    $NC $NC_ARGS
  ) |
  (
    ## Receive other public key
    sed '/-----END PUBLIC KEY-----/q' >"$SKYF0L_PUBLIC_KEY_PATH".tmp
    verbose_echo "Other public key received"
    mv "$SKYF0L_PUBLIC_KEY_PATH".tmp "$SKYF0L_PUBLIC_KEY_PATH"

    ## Wait for other public key to be received by read loop
    sleep .3

    ## Write to stdout loop
    while IFS= read -r OUT; do
      echo "$OUT" | $BASE64 -d | $OPENSSL pkeyutl -decrypt -inkey "$MY_KEY_PATH"
      echo
    done
  )
