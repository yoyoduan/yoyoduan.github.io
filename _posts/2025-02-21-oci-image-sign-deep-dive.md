---
title: OCI Image Sign Deep Dive
date: 2025-02-21 18:38:00 +0800
description: The blog is to describe what happens behind the scenes when signing and verifying an OCI image.
categories: [Blogging, OCI]
tags: [oci-image, signature, notation]
media_subpath: /assets/img/oci-image/
---

## Introduction
Imagine you are a skilled software developer who has worked hard to create a new Docker image designed to solve specific pain points for your users. After building and publishing the image, you might expect users to adopt it quickly.

However, they could hesitate—not because your image lacks quality, but due to compliance and security concerns. If you simply publish the image without any form of verification, your users might ask:

- Has the image been tampered with after it was built?
- Was the image truly built and published by you, or is it from an unknown source?
- Is the image still maintained, or has it been deprecated?
- ...

To address these concerns, a reliable solution is to sign the image and distribute its signature along with your public key. This allows users to verify the signature and ensure[^1]:

- Integrity – The image has not been modified after signing, and the signature remains valid.
- Authenticity – The signature is issued by a trusted identity, confirming the image’s source.
- Trusted Timestamping – The signature was created when the signing key/certificate was valid.
-Expiry – (Optional) The signature can specify an expiration date to indicate image validity.
- Revocation Check – Users can verify whether the signing identity is still trusted.
By signing an image, you provide a cryptographic guarantee that helps users confidently adopt your image.

In this blog, I’ll walk you through the process of signing an OCI image and verifying it using Notation, a command-line interface (CLI) tool that integrates image signatures into the OCI registry ecosystem. Along the way, we’ll explore what happens behind the scenes during the signing and verification process.

## Tools & Setup
The following tools and resources are used to follow along with this blog:
- Docker – Installed and running.
- Notation CLI – Installed for signing and verifying OCI images.
- ORAS CLI – Installed for working with OCI artifacts.
- Container Registry – A registry to store and manage signed images. In this blog, I use Azure Container Registry (ACR) with the endpoint `yoyoociacr.azurecr.io`
  ![acr resource screenshot](yoyoociacr-screenshot.png)

## References
[^1]:Notary project specification signature verification details. Available at: [signature-verification-details](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/trust-store-trust-policy.md#signature-verification-details).
