# railway-proton-mail-bridge

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/proton-mail-bridge?referralCode=HxrUPo&utm_medium=integration&utm_source=template&utm_campaign=generic)

Run [hydroxide](https://codeberg.org/emersion/hydroxide), an open-source Proton Mail bridge, on [Railway](https://railway.com). It exposes your Proton Mail account over IMAP, SMTP and CardDAV.

The Dockerfile builds hydroxide from the latest Codeberg source. Older builds from the GitHub mirror can't pass Proton's CAPTCHA check.

## 1. Log in locally

Proton usually asks for a CAPTCHA, and hydroxide only takes passwords on a terminal, so log in on your own machine (requires Go 1.26+):

```bash
git clone https://codeberg.org/emersion/hydroxide.git
cd hydroxide && go build ./cmd/hydroxide
./hydroxide auth <your-proton-address>
```

If it prints a `verify.proton.me` link, open it, solve the CAPTCHA, then press Enter. Enter your TOTP code if 2FA is on.

Save the **bridge password** it prints. Your mail client logs in with it, and it can't be recovered later.

Then encode the saved session:

```bash
# Linux
base64 -w0 ~/.config/hydroxide/auth.json
# macOS
base64 -i ~/Library/Application\ Support/hydroxide/auth.json
```

## 2. Deploy on Railway

The **Deploy on Railway** button above sets up the service and the `/data` volume and asks for the variables below. To set it up by hand instead:

1. Create a service from this repo.
2. Attach a volume mounted at `/data`. hydroxide saves refreshed tokens there.
3. Set the variables:

| Variable | Required | Description |
| --- | --- | --- |
| `HYDROXIDE_AUTH_JSON_B64` | yes | The base64 output from step 1. Used only when `/data` has no `auth.json` yet. |
| `HYDROXIDE_AUTH_FORCE` | no | Set to `1` for one deploy to overwrite the stored `auth.json` (for example after logging in again). Remove it afterwards. |
| `PORT` | no | CardDAV port, default `8080`. |

Run a single replica only.

## 3. Connect

| Service | Port | Login |
| --- | --- | --- |
| IMAP | 1143 | your Proton address and the bridge password |
| SMTP | 1025 | your Proton address and the bridge password |
| CardDAV | `$PORT` (8080) | your Proton address and the bridge password |

- **Private networking (recommended):** other services in the same Railway project connect to `<service-name>.railway.internal`.
- **Public IMAP/SMTP:** these need a Railway TCP proxy for each port. hydroxide accepts plaintext logins when no TLS certificate is configured, so don't expose these ports publicly without TLS.
- **CardDAV** is HTTP and can use a normal Railway public domain, which provides HTTPS.

## Several accounts

`auth.json` holds one entry per account. Run `hydroxide auth` for each account on the same machine, then encode the file once.
