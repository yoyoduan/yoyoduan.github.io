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
    ![pushed OCI image](oci-image-screenshot.png)
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

### 2. Sign the OCI Image
#### 2.1 Verify no Existing Signatures
With the certificate prepared, proceed to sign the OCI image. Before signing, verify that the image does not have any existing signatures:

```powershell
$REGISTRY_URL="yoyoociacr.azurecr.io"
$IMAGE="$REGISTRY_URL/oci-artifacts:v1.0"

notation ls $IMAGE
```

Expected Output:
```text
yoyoociacr.azurecr.io/oci-artifacts@sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675 has no associated signature
```
This indicates that there are no signatures associated with the image currently.

#### 2.2 Sign the OCI Image
Now, sign the OCI image using the previously generated key. We can use the `--key` to specify which one is used to sign the OCI image.
```powershell
notation sign $IMAGE --key yoyo-duan.io
```

Upon successful signing, you'll receive a confirmation message:
```text
Successfully signed yoyoociacr.azurecr.io/oci-artifacts@sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675
```

To confirm the signature has been applied, list the signatures associated with the image:
```powershell
notation ls $IMAGE
```

The output will display the signature details:
```text
yoyoociacr.azurecr.io/oci-artifacts@sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675
└── application/vnd.cncf.notary.signature
    └── sha256:b3d288872d003b0d31a26522dbf836184f229288b57dff2621f1ee8e48034cd9
```

#### 2.3 Understanding the Signature
Notably, the original OCI image digest (sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675) remains unchanged, indicating that the image itself has not been altered. Instead, a new artifact with the media type `application/vnd.cncf.notary.signature` has been associated with the image. This artifact represents the signature.

Let's delve into its the manifest of the signature to understand this association better:
```powershell
oras manifest fetch yoyoociacr.azurecr.io/oci-artifacts@sha256:b3d288872d003b0d31a26522dbf836184f229288b57dff2621f1ee8e48034cd9
```

The output is:
```json
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.oci.image.manifest.v1+json",
    "subject": {
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "digest": "sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675",
        "size": 605
    },
    "layers": [
        {
            "mediaType": "application/jose+json",
            "digest": "sha256:cb71e04d24a01cbdabef808730b93e0d642898040158c2528c85194fe4076dff",
            "size": 2093
        }
    ],
    "config": {
        "mediaType": "application/vnd.cncf.notary.signature",
        "digest": "sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a",
        "size": 2
    },
    "annotations": {
        "io.cncf.notary.x509chain.thumbprint#S256": "[\"964fa9b514e84d60d8549743ae6830f7140f81b291f137399a65b860677dcddf\"]",
        "org.opencontainers.image.created": "2025-02-08T09:41:02Z"
    }
}
```

There are four noticable fields [^2]:
1. The `subject` field references the manifest of the artifact being signed. It contains the digest of the original OCI image's manifest, indicating which image the signature pertains to. Notably, this association is made by the signature pointing to the original image, rather than the image containing a reference to its signature. This association relationship is showed up in the below graph with dash line arrow from `subject` in the signature manifest to the OCI image manifest.

2. The `config.mediaType` specifies the type of the configuration. In the case of Notary Project signatures, this is set to `application/vnd.cncf.notary.signature`, indicating that the manifest represents a signature. 

3. The `annotations` field is a collection of annotations. A required annotation is `io.cncf.notary.x509chain.thumbprint#S256`, which contains the SHA-256 fingerprints of the signing certificate and its chain. In scenarios where a self-signed certificate is used, this annotation will have a single SHA-256 fingerprint corresponding to that certificate `yoyo-duan.io.crt`. 

4. The `layers` array references the actual signature content, known as the signature envelope. This envelope is stored as a layer with a media type indicating its format, such as `application/jose+json` for JWS (JSON Web Signature) or `application/cose` for COSE (CBOR Object Signing and Encryption). The signature envelope encapsulates the signed data and the signature itself.
![notary signature specification](signature-specification.png)

#### 2.4 Deep Dive to the Signature Envelope
The official definition of signature envelope is a standard data structure for creating a signed message. However, the definition is too general to understand. To comprehend this better, let's fetch the content of the signature envelope in our example.

Though the signature envelope only supports two envelope formats, JWS[^4] and COSE[^5], as they are essentially similar, I will use the `JWS` format for illustration, corresponding to the `application/jose+json` in the output of the manifest in our example `layers[0].mediaType`.

```powershell
oras blob fetch yoyoociacr.azurecr.io/oci-artifacts@sha256:cb71e04d24a01cbdabef808730b93e0d642898040158c2528c85194fe4076dff --output signature-envelope.json
```

The output is stored in a local file called `signature-envelope.json` and its content is in json format:
```json
{
    "payload": "eyJ0YXJnZXRBcnRpZmFjdCI6eyJkaWdlc3QiOiJzaGEyNTY6ZjE3ZmJjN2RlYmM0ZWRhNzQ1NmRkM2FiMGMxOGMyN2Q1MDgyMWE5ODIxY2ZjYTU2MDc0MDRlNjU0Zjc2ZTY3NSIsIm1lZGlhVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5vY2kuaW1hZ2UubWFuaWZlc3QudjEranNvbiIsInNpemUiOjYwNX19",
    "protected": "eyJhbGciOiJQUzI1NiIsImNyaXQiOlsiaW8uY25jZi5ub3Rhcnkuc2lnbmluZ1NjaGVtZSJdLCJjdHkiOiJhcHBsaWNhdGlvbi92bmQuY25jZi5ub3RhcnkucGF5bG9hZC52MStqc29uIiwiaW8uY25jZi5ub3Rhcnkuc2lnbmluZ1NjaGVtZSI6Im5vdGFyeS54NTA5IiwiaW8uY25jZi5ub3Rhcnkuc2lnbmluZ1RpbWUiOiIyMDI1LTAyLTA4VDE3OjQxOjAyKzA4OjAwIn0",
    "header": {
        "x5c": [
            "MIIDSjCCAjKgAwIBAgIBfzANBgkqhkiG9w0BAQsFADBUMQswCQYDVQQGEwJVUzELMAkGA1UECBMCV0ExEDAOBgNVBAcTB1NlYXR0bGUxDzANBgNVBAoTBk5vdGFyeTEVMBMGA1UEAxMMeW95by1kdWFuLmlvMB4XDTI1MDIwODA5MzkwOVoXDTI1MDIwOTA5MzkwOVowVDELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAwDgYDVQQHEwdTZWF0dGxlMQ8wDQYDVQQKEwZOb3RhcnkxFTATBgNVBAMTDHlveW8tZHVhbi5pbzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANu3ZSuxBE2JCktDKhuMOx0lCFEfJmAsIH+rPY2Av9vkNv6b8uAUZIFFXLwoPpRb7xHthCUp6zbTcDUKKdZkR5nhVhcZOJuuCJUyFi6vthDO2B81JQjlLKkrD2HJH8B/GSCjnJvSFnQKpFJbUxKUpTbqgt0VCux5hw6lSroRe7WdDMD7i/8a/e9JxLCNOf4k0bvGEHhpus0GdmF+LKFYeYnyuCB4mQ60rwGay72PSLpsWCHEKEFHQCFzvawq2v4yOYvgugGB4d9CBWI/7iuq82EZnWX3zt1+NjIeUb6GMSJ3OldfejdaOtNusAsJ9Vp+jXlqPdduRVDKpmxnIgTQPzMCAwEAAaMnMCUwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA0GCSqGSIb3DQEBCwUAA4IBAQAdsM6Q6jlVDyHYEDCv7L0F8pHvAmN1FyBAoieJ9bNssD1ZC9r6jK+6URlwA+C/NUHjBRbGdBGtnI6yENkAjc9WGv/H4TOKwMVUxkQyKp5XsPoCqFdJk/NUjhptlv47NRCXTPkQOjth+mRLgw0nZD9u0dhFXPs4ybWqN4l6Ne5g8IhLSr0VnILgPRR3YI0BK2TIzDKmEQddjEwpPPhks6LZKJ8QvpIFAgT59IgT6KaAbv2KNCfm+M6z5WH9YtLP/7br95JZARjNmqrN80u0lyBYCYECg/Xq9tc0qFLc088E3W6BMz4q7IAp84h+HvbsIWyoD8jpwoGKHqCW/3hnJTxG"
        ],
        "io.cncf.notary.signingAgent": "notation-go/1.3.0"
    },
    "signature": "1_18FOc2U3efzeoTr6P4XYPd7yf7P649j1XZ4ayUa5ONxVXC4zxXHtQjI5zLqIhtwAfe_RFNRNbVjQ-fsaAtmue9AJxx12QrxuY1btZJ-YFgO_l0ifkUUgP907w4ZjqxwchoYFmrsV34t-0T4G1ULgTjOGEL3hxIyQNjHWkQKEWlZ4_MIESysybilBiBZLe31ccbZc4aNZq9dSKqhNAXKcQIYywyuj4aaiRCnG-SD-56dzGpcEWE7HUKBa4iUe2HyUtp9N4SYOFyQChzH7nYtE_KgQqg6lygEVmuNFbL6tSvrtSq3t2TC6N8PBHYANLTxC9HaMi_FzWpplJvDM2Q8g"
}
```
{: file="signature-envelope.json" }

You can find that a signature envelope comprises of four components[^3] which values are computed by the following method:
```yaml
{
    "payload": "<Base64Url(JWSPayload)>",
    "protected": "<Base64Url(ProtectedHeaders)>",
    "header": {
        "io.cncf.notary.timestamp": "<Base64(TimeStampToken)>",
        "x5c": ["<Base64(DER(leafCert))>", "<Base64(DER(intermediateCACert))>", "<Base64(DER(rootCert))>"]
        # more...
    },
    "signature": "Base64Url( sign( ASCII( <Base64Url(ProtectedHeader)>.<Base64Url(JWSPayload)> )))"  
}
```

1. Payload/Message `payload`: the data that is integrity protected. The value equals to `Base64Url(JWSPayload)>`. As for the value of `JWSPayload`, it is the manifest of the artifact being signed - same to the `subject` of signature manifest- corresponding to the dash arrow from the `payload` to manifest of original OCI image in the above graph. To validate this, we can decode the Base64Url-encoded `payload` to retrieve the original JSON descriptor:
  ```
  DecodeBase64(payload) =
  DecodeBase64(eyJ0YXJnZXRBcnRpZmFjdCI6eyJkaWdlc3QiOiJzaGEyNTY6ZjE3ZmJjN2RlYmM0ZWRhNzQ1NmRkM2FiMGMxOGMyN2Q1MDgyMWE5ODIxY2ZjYTU2MDc0MDRlNjU0Zjc2ZTY3NSIsIm1lZGlhVHlwZSI6ImFwcGxpY2F0aW9uL3ZuZC5vY2kuaW1hZ2UubWFuaWZlc3QudjEranNvbiIsInNpemUiOjYwNX19) = 
  {
      "targetArtifact": {
          "digest": "sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675",
          "mediaType": "application/vnd.oci.image.manifest.v1+json",
          "size": 605
      }
  }
  ```

1. Signed attributes `protected`: the signature metadata that is integrity protected - e.g. the algorithm used, signature expiration time, creation time and etc. Decoding the Base64Url-encoded protected field reveals a JSON object with these details:
  ```
  DecodeBase64(protected) =
  DecodeBase64(eyJhbGciOiJQUzI1NiIsImNyaXQiOlsiaW8uY25jZi5ub3Rhcnkuc2lnbmluZ1NjaGVtZSJdLCJjdHkiOiJhcHBsaWNhdGlvbi92bmQuY25jZi5ub3RhcnkucGF5bG9hZC52MStqc29uIiwiaW8uY25jZi5ub3Rhcnkuc2lnbmluZ1NjaGVtZSI6Im5vdGFyeS54NTA5IiwiaW8uY25jZi5ub3Rhcnkuc2lnbmluZ1RpbWUiOiIyMDI1LTAyLTA4VDE3OjQxOjAyKzA4OjAwIn0) =
  {
      "alg": "PS256",
      "crit": [
          "io.cncf.notary.signingScheme"
      ],
      "cty": "application/vnd.cncf.notary.payload.v1+json",
      "io.cncf.notary.signingScheme": "notary.x509",
      "io.cncf.notary.signingTime": "2025-02-08T17:41:02+08:00"
  }
  ```

1. Unsigned attributes `header`: these attributes are not signed by the signing key that generates the signature, e.g. certificate chains signed by a Certificate Authority (CA) or timestamp tokens from a Time Stamping Authority (TSA). These headers provide additional context or verification data but are not integrity-protected by the signature itself.

2. Cryptographic signatures `signature`: this is the actual digital signature computed over the payload and the protected headers.  The signature is generated by signing the ASCII representation of the concatenated Base64Url-encoded protected headers and payload: `Base64Url( sign( ASCII( <Base64Url(ProtectedHeader)>.<Base64Url(JWSPayload)> )))`. 

### 3. Publish the OCI Image Path and Public Key
Congratulations on successfully signing your OCI image! 

Now, it comes the final steps developers need to do to ensure the users can confidently access and verify the authenticity of the signed image:
1. Share the exact path of signed OCI image: `yoyoociacr.azurecr.io/oci-artifacts:v1.0`.
2. Distribute the public key `yoyo-duan.io.crt` with the users.

## References
[^1]:Notary project specification signature verification details. Available at: [signature-verification-details](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/trust-store-trust-policy.md#signature-verification-details).
[^2]:Notary Signature Specification Storage. Available at: [signature-specification](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/signature-specification.md)
[^3]:Notary Signature Envelope. Available at: [signature-envelope](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/signature-specification.md#signature-envelope)
[^4]:Signature Envelope JWS. Available at: [signature-envelope-jws](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/signature-envelope-jws.md).
[^5]:Signature Envelope COSE. Available at: [signature-envelope-cose](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/signature-envelope-cose.md).
