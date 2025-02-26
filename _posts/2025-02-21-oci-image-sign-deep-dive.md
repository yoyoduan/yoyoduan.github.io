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
1. **Docker** – Installed and running.
2. **Notation CLI** – Installed for signing and verifying OCI images.
3. **ORAS CLI** – Installed for working with OCI artifacts.
4. **Container Registry** – A registry to store and manage signed images. In this blog, I use Azure Container Registry (ACR) with the endpoint `yoyoociacr.azurecr.io`
  ![acr resource screenshot](yoyoociacr-screenshot.png)
5. **OCI Image**: A test OCI image pushed to the above container registry. 
    ![pushed OCI image](/oci-image-screenshot.png)
    <details>    
    <summary>Click to expand to check the steps to create this image.</summary>
    <pre>
    a. Create a Local Directory
    Create a directory named `oci-artifacts` and add two YAML files: `pod.yaml` and `kustomization.yaml`:
    ```
    oci-artifacts/
    ├── pod.yaml
    └── kustomization.yaml
    ```

    b. Define the pod.yaml File
    ```yaml
    apiVersion: v1
      kind: Pod
      metadata:
        name: yoyo-pod
      spec:
        nodeSelector:
        kubernetes.io/os: linux
        containers:
        - image: mcr.microsoft.com/mirror/docker/library/nginx:1.23
        name: nginx-azuredisk
        resources:
          requests:
          cpu: 100m
          memory: 128Mi
          limits:
          cpu: 250m
          memory: 256Mi
    ```
    {: file="pod.yaml" }

    c. Define the kustomization.yaml File
    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
    - pod.yaml
    ```
    {: file="kustomization.yaml" }

    d. Package the Artifacts
    Navigate to the parent directory of oci-artifacts and create a tarball:
    ```powershell
    tar -czf oci-artifacts.tar.gz oci-artifacts/
    ```

    e. Use ORAS CLI to push the tarball to the Container Registry:
    ```powershell
    # Define registry variables
    $REGISTRY_URL="yoyoociacr.azurecr.io"
    $USERNAME="yoyoociacr"
    $IMAGE_NAME="oci-artifacts"
    $IMAGE_TAG="v1.0"
    
    # Log in to ACR
    docker login $REGISTRY_URL -u $USERNAME -p <password>
    
    # Push the OCI artifact
    oras push $REGISTRY_URL/oci-artifacts:v1.0 oci-artifacts.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
    ```  

    Upon successful push, you'll receive a confirmation with the artifact's digest.

## OCI Image Signing Steps for Developers
In this section, we'll walk through the process of signing an OCI image. All the steps are for developers.

### 1. Preparing a Certificate
To sign an image, a certificate is required. For demonstration purposes, I'll generate a self-signed certificate using the Notation CLI's `notation cert generate-test` command. This command creates a test RSA key and a corresponding self-signed X.509 certificate. It's important to note that this self-signed certificate is intended for testing or development purposes only.
```powershell
notation cert generate-test "yoyo-duan.io"
```

Upon execution, the following output is produced:
```text
generating RSA Key with 2048 bits
generated certificate expiring on 2025-02-09T09:39:09Z
wrote key: <path-to-the-notation>/localkeys/yoyo-duan.io.key
wrote certificate: <path-to-the-notation>/notation/localkeys/yoyo-duan.io.crt
Successfully added yoyo-duan.io.crt to named store yoyo-duan.io of type ca
yoyo-duan.io: added to the key list
```

To verify the generated key and certificate, use the command:
```powershell
notation key ls
```

The output will display:
```text
NAME             KEY PATH                                            CERTIFICATE PATH
* yoyo-duan.io   <path-to-the-notation>/localkeys/yoyo-duan.io.key   <path-to-the-notation>/notation/localkeys/yoyo-duan.io.crt
```

In this output:
- **KEY PATH**: Indicates the location of the private key file.
- **CERTIFICATE PATH**: Indicates the location of the public certificate file.

For production environments, it's recommended to use a certificate issued by a trusted Certificate Authority (CA) to ensure security and trustworthiness.

## References
[^1]:Notary project specification signature verification details. Available at: [signature-verification-details](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/trust-store-trust-policy.md#signature-verification-details).
