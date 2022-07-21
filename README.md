# NcEnc

Netcat wrapper to encrypt network traffic with openssl.

## What is NcEnc?

With netcat/nc, the data is sent over the network in clear text and anyone with too much permission can read it. NcEnc is a wrapper that will encrypt the traffic passing through the netcat tunnel. It doesn't need any package to install, only the default packages in linux: `nc`, `openssl` and `base64`.

## How to use NcEnc?

It's very simple. Just run `ncenc.sh` instead of `nc`.

```bash
# Start listening on port <port>
$ ncenc.sh -vlp <port>
# Connect to <ip> on port <port>
$ ncenc.sh -v <ip> <port>
```

You can also curl the script and run it directly.

```bash
# Start listening on port <port>
$ (curl -sL https://raw.githubusercontent.com/skyf0l/NcEnc/main/ncenc.sh; cat) | sh -s -- -vlp <port>
# Connect to <ip> on port <port>
$ (curl -sL https://raw.githubusercontent.com/skyf0l/NcEnc/main/ncenc.sh; cat) | sh -s -- -v <ip> <port>
```

## How encryptions works?

Basically, at start of NcEnc server and client, a RSA key is generated and sent to both sides. The server will use the public key of client to encrypt the data and use its private key to decrypt the data. And back again.

Messages are encrypted and sent over the network line by line. Currently, it is not possible to have a more interactive netcat because of RSA encryption times.

In terms of security, it is impossible for someone to decrypt the communications (e.g. with an MITM attack).

## Todo

- Store RSA keys in memory instead of files (for better privacy)
- Handle and exit on error (currently not handled due to pipe behavior)
- Exchange an AES key and encrypt/decrypt messages with it to speed up encryption (like the SSL protocol).
