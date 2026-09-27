# Vory Privacy Policy

*Last updated: 26 September 2026 · Applies to the Vory iPhone app, its Apple Watch app and
extensions, the Vory Companion plugin, and the Vory push relay.*

Vory is a remote control for a Hermes agent gateway that **you** run. The short version: your
conversations, your agents and your settings live on your phone and on your gateway. Vory has no
accounts, no analytics, and no servers that can read your messages. The one service we operate
— the push relay — carries encrypted notifications it cannot open.

## What Vory is

Vory connects your iPhone to a Hermes gateway you host (on your own computer, home network,
Tailscale network or Cloudflare tunnel). Everything you do in the app — chatting with your
agents, approving their actions, changing their settings — is a request from your phone to your
gateway. We are not in that path.

## Data on your phone

Vory stores the following on your device only:

- **Gateway connection details** — the gateway's address and the token or sign-in credentials
  you enter, kept in the iOS Keychain.
- **Conversation cache** — recent transcripts, so chats open instantly and work offline. Stored
  in the app's cache directory; iOS may clear it, and deleting the app removes it.
- **Bot looks and preferences** — the shapes, eyes and colours you give your bots, and your
  settings. Stored in the app's local storage.
- **Widget state** — the small snapshot the Live Activity, widgets and Watch complications draw
  from (which bot is working and what phase it is in), kept in the app's Keychain group so the
  extensions can read it.
- **Push credentials** — if you turn on notifications, an install identifier, a secret and an
  encryption key that Vory generates on your phone (see *Notifications*).

None of this is sent to us.

## Data on your gateway

Your gateway holds your conversations, your agents' configuration, and — when notifications are
on — a small device file Vory writes so the gateway can reach your phone. Your gateway is yours:
its storage, backups and the models it calls are governed by how you set it up and by the
policies of any AI providers you have configured there. Vory does not change that.

## Notifications and the push relay

Apple delivers notifications to iPhones only through its Apple Push Notification service, which
requires a developer's server. We run a small one — the **Vory push relay** — so your gateway can
notify your phone without you needing an Apple developer account.

How it works, and what the relay can and cannot see:

- When you enable notifications, Vory creates an **install identifier**, a **secret** and an
  **encryption key** on your phone and writes them to your gateway. The relay receives the
  install identifier, the secret and your device's push token. **It never receives the
  encryption key.**
- When your gateway has something to tell you (a reply, a request for approval, a Live Activity
  update), the Vory Companion plugin on your gateway encrypts it with that key and posts the
  ciphertext to the relay. The relay forwards it to Apple; your phone decrypts it.
- The relay therefore sees: install identifiers, device push tokens, and encrypted payloads it
  cannot read. It keeps the registration (identifier, token, secret) for as long as your
  registration is active and deletes it when you turn notifications off or the token becomes
  invalid. It does not keep the payloads. It does not log message contents.
- The relay is hosted on Cloudflare Workers. Cloudflare's own infrastructure logs (such as
  request IP addresses) are governed by [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/).
- Apple's delivery of notifications is governed by [Apple's privacy policy](https://www.apple.com/legal/privacy/).

You can turn notifications off at any time in Settings › Companion; Vory then deletes the
registration from the relay.

## Features that work on the device

- **Vory Summaries** (beta) uses Apple Intelligence on your iPhone to title and summarise chats
  in the list. The text is processed on the device by Apple's on-device model; it is not sent to
  us or to Apple's servers by Vory.
- **Dictation and voice memos** use Apple's speech recognition. Vory asks for on-device
  recognition where the device supports it; otherwise Apple's speech service may process the
  audio under Apple's privacy policy.
- **Photos, camera and files** are only accessed when you choose to attach something, and the
  attachment goes to your gateway, nowhere else.
- **Motion** (the bots tilting with your phone) uses the motion sensors on the device only. It is
  off by default.
- **Local network** access is used only to reach a gateway on your own network.

## What we do not do

- No accounts. No sign-up. No email list from the app.
- No analytics, no advertising identifiers, no tracking, no third-party SDKs.
- No copies of your conversations, tokens or settings on any server we control.
- No selling or sharing of data. There is nothing to sell.

## TestFlight

During the beta, Vory is distributed through Apple's TestFlight. If you install it that way,
Apple may collect crash logs and usage statistics and share them with us in anonymised form, and
you can send feedback with screenshots through TestFlight. That is governed by
[Apple's TestFlight terms](https://www.apple.com/legal/internet-services/itunes/testflight/) and
Apple's privacy policy. Anything you put in a feedback message comes to us; don't include
secrets.

## Children

Vory is not directed at children under 13 and does not knowingly collect information from them.

## Changes

If this policy changes, the date at the top changes and the new version is published at this
address. Material changes that affect the relay will also be noted in the app's release notes.

## Contact

Questions about this policy or your data: **matt@vory.dev**.

*Vory is not affiliated with Nous Research or the Hermes project.*
