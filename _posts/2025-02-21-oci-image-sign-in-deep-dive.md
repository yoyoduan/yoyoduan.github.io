---
title: OCI Image Sign in Deep Dive
date: 2025-02-21 18:38:00 +0800
categories: [Blogging, OCI]
tags: [oci-image, signature, notation]
---

# OCI Image Sign in Deep Dive

Everyone knows the importances of compliance and security. In the container world, signing is an inevitable operation to ensure the image's integrity and the authenticity. Therefore, in this blog, I would like to use the Notation, a command-line interface(CLI) tool to add signatures as standard items in the OCI registry ecosystem, a simplied self built OCI artifacts and an Azure Container Registry as an example to explain what happened in the backend and understand the image sign process.

- integrity (artifact is unaltered, signature is not corrupted)
- authenticity (the signature is really from the identity that claims to have signed it)
[Refer to: https://github.com/notaryproject/specifications/blob/v1.0.0/specs/trust-store-trust-policy.md]

What you can learn
Notary trust store and trust policy

# Prerequsite
- Docker installed and running
- Notation CLI installed
- ORAS CLI installed
- An Azure Container Registry resource is created
  This is my Azure Container Registry with Login Server yoyoociacr.azurecr.io
  [page 1 image]

# Before going deep, what you need to know:
1. When signing an image, the image itself doesn't change. Which means the image's layers does not add any signuare layer to the image and the image sha remains the same.
  You might have the questions:
  [1] If the image remains the same, where is the signature?
  [2] How does the signature link to the original image?
  [3] When copying the image to another container registry, how can I copy both the image and its signature together? 
2. The signing process actually does not try to sign the full image. Instead, it signs the image's imagesha and other necessary metadata of this image.
  You might have the questions:
  [4] Which fields will be signed.

Don't hurry up. all the answers of the three questions are in the blog. Please go through it and I promise that it is easy to understand.

# Image Sign Steps
## 1. Create an OCI artifact and push it to the Azure Container registry.
Firstly, I create a local directary and store two yaml files under my local directory `oci-artifacts`.
```
oci-artifacts
├── pod.yaml
└── kustomization.yaml
```
[Create a specific repo to store the OCI artifacts files]

```yaml
# The pod.yaml content
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
    volumeMounts:
      - name: azuredisk
        mountPath: /mnt/azuredisk
        readOnly: false
  volumes:
    - name: azuredisk
      persistentVolumeClaim:
        claimName: pvc-azuredisk
---
# The kustomization.yaml content
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- pod.yaml
```

```bash
tar -czf oci-artifacts.tar.gz oci-artifacts/

# Login the ACR
$REGISTRY_URL="yoyoociacr.azurecr.io"
$USERNAME="yoyoociacr"
docker login $REGISTRY_URL -u $USERNAME -p <password>

# Push the OCI artifacts to the remote ACR
oras push $REGISTRY_URL/oci-artifacts:v1.0 oci-artifacts.tar.gz:application/vnd.oci.image.layer.v1.tar+gzip
✓ Uploaded  oci-artifacts.tar.gz                                                                           513/513  B 100.00%  471ms
  └─ sha256:b3f0b4c7a7ff25d47e19f801718569ad39b3c2aeb2cf26b19312cb74afadc10a
✓ Uploaded  application/vnd.oci.empty.v1+json                                                                  2/2  B 100.00%  343ms
  └─ sha256:44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a
✓ Uploaded  application/vnd.oci.image.manifest.v1+json                                                     605/605  B 100.00%  279ms
  └─ sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675
Pushed [registry] yoyoociacr.azurecr.io/oci-artifacts:v1.0
ArtifactType: application/vnd.unknown.artifact.v1
Digest: sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675
```
[page 2 image]

## 2. Generate a test key and self-signed certificate
To sign a image, we need a certifcates. To test, we can leverage the notation CLI to create a test key and self-signed certificate.
```bash
# Generate the test key
# With the --default flag, the test key is set as a default signing key.
notation cert generate-test --default "yoyo-duan.io"

generating RSA Key with 2048 bits
generated certificate expiring on 2025-02-09T09:39:09Z
wrote key: <path-to-the-notation>\localkeys\yoyo-duan.io.key
wrote certificate:<path-to-the-notation>\notation\localkeys\yoyo-duan.io.crt
Successfully added yoyo-duan.io.crt to named store yoyo-duan.io of type ca
yoyo-duan.io: added to the key list
yoyo-duan.io: mark as default signing key

# Check the key
notation key ls
NAME             KEY PATH                                                             CERTIFICATE PATH
    ID   PLUGIN NAME
* yoyo-duan.io   <path-to-the-notation>\localkeys\yoyo-duan.io.key   <path-to-the-notation>\notation\localkeys\yoyo-duan.io.crt

# Check the cert
notation cert ls
STORE TYPE   STORE NAME     CERTIFICATE
ca           yoyo-duan.io   yoyo-duan.io.crt
```
In the output of `notation cert ls`, you can see the new cert is in the `ca` store type and the name is `yoyo-duan.io` which is specified `notation cert generate-test --default "yoyo-duan.io"`. This matters when later verifying the signature. 

In the Notary Project, there is a concept called "Trust store". See below example, the trust store is indeed a directory location, under which each sub directory is considered a named store, e.g. `yoyo-duan.io`. Each named store contains zero or more certificate files which are expected to contain certificate(s) with extension `.pem`, `.crt` and `.cer`. And also noted the certificates in a trust store should be the root certificates. And that's the reason why we used a self-signed cert in the blog.

```
$XDG_CONFIG_HOME/notation/trust-store
    /x509
        /ca
            /yoyo-duan.io
                yoyo-duan.io.crt
            /acme-rockets-ca  # all the certs below are examples for explanation what the trust store is, therefore they are not in the output of notation cert ls
                cert.pem
            /wabbit-networks
                cert1.crt
        /signingAuthority
            /acme-network-sa
                cert10.pem
        /tsa
            /publicly-trusted-tsa
                tsa-cert1.pem
```

There are three store types which correspond to the the directly sub-directory of `/x509`. You can see the `yoyo-duan.io` named store is under `ca`, so its store type is `ca`. When verifying the image signed by the key of `yoyo-duan.io` cert, you should specify to use the named store `ca:yoyo-duan.io`. As for how to specify the named store, it will be explained in the [Verification](#TODO) section. Now you only need to remember that you generated a test key and self-signed certificate, and it is added as a named store in the `ca:yoyo-duan.io`.

| Sub Directory Name | Identity                     | Explanation                                                  |
| ------------------ | ---------------------------- | ------------------------------------------------------------ |
| ca                 | Certificates                 | It contain Certificate Authority (CA) root certificates.     |
| signingAuthority   | SigningAuthority Certificate | It contains Siging Authority's root certificates.            |
| tsa                | Timestamping Certificates    | It contains Time Stamping Authority (TSA) root certificates. |

More details can be found in the [Trust Store and Trust Policy Specification](https://github.com/notaryproject/specifications/blob/v1.0.0/specs/trust-store-trust-policy.md)


## 3. Sign the OCI artifacts
```bash
# List the signatures associated with the container image before sign
$IMAGE="$REGISTRY_URL/oci-artifacts:v1.0"

notation ls $IMAGE
yoyoociacr.azurecr.io/oci-artifacts@sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675 has no associated signature

notation sign $IMAGE
Successfully signed yoyoociacr.azurecr.io/oci-artifacts@sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675

# List the signatures associated with the container image after sign
notation ls $IMAGE
yoyoociacr.azurecr.io/oci-artifacts@sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675
└── application/vnd.cncf.notary.signature
    └── sha256:b3d288872d003b0d31a26522dbf836184f229288b57dff2621f1ee8e48034cd9
```

You can find that before and after the sign, the original image's sha does not change, meaning no change of the original image. But the image refered to another "image"(not accurate) with media type `application/vnd.cncf.notary.signature`. When we go to the ACR, you can see a new item is generated.
[page 3 image]

Let's go deep to the new item by checking its manifest.
```json
oras manifest fetch yoyoociacr.azurecr.io/oci-artifacts:sha256-f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.oci.image.index.v1+json",
    "manifests": [
        {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "digest": "sha256:b3d288872d003b0d31a26522dbf836184f229288b57dff2621f1ee8e48034cd9",
            "size": 728,
            "annotations": {
                "io.cncf.notary.x509chain.thumbprint#S256": "[\"964fa9b514e84d60d8549743ae6830f7140f81b291f137399a65b860677dcddf\"]",
                "org.opencontainers.image.created": "2025-02-08T09:41:02Z"
            },
            "artifactType": "application/vnd.cncf.notary.signature"
        }
    ]
}
```
As you see, the `mediaType` is `application/vnd.oci.image.index.v1+json` which means the new item is an OCI Image Index. What Is an OCI Image Index?
- It is a collection of image manifests.
- It does not contain actual image layers but instead references multiple manifests.
- It can reference artifacts like SBOMs or signatures.


As there is only one `manifests` and its artifactType is `application/vnd.cncf.notary.signature`, it refers to the Notary Project Signature Manifest. Let's check its manifest content:

```json
oras manifest fetch yoyoociacr.azurecr.io/oci-artifacts@sha256:b3d288872d003b0d31a26522dbf836184f229288b57dff2621f1ee8e48034cd9
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
[TODO: page 4 image]
In fact, if we go to the signed image, we can see in its `Referres`, this Notary Project Signature Manifest is linked. 

There are 4 required fields need your attention:
- subject: The answer of the question `[2] The image remains the same, how does the signature link to the original image?` is here. Y ou can see the `subject.digest`, the imagesha is the original image's sha. And therefore, it is the Notary Project Signature Manifest point to the original image manifest, rather than the original image point to the signature.
- layers: It contains one and only one item referencing the signature envelope. A new term `signature envelope` which only support two types: `JWS`(when mediaType application/jose+json) and `COSE`(mediaType: application/cose) is induced. The `signature envelope` compose of below 4 parts:
```json
{
    "payload": "<Base64Url(JWSPayload)>",
    "protected": "<Base64Url(ProtectedHeaders)>",
    "header": {
        "io.cncf.notary.timestamp": "<Base64(TimeStampToken)>",
        "x5c": ["<Base64(DER(leafCert))>", "<Base64(DER(intermediateCACert))>", "<Base64(DER(rootCert))>"]
    },
    "signature": "Base64Url( sign( ASCII( <Base64Url(ProtectedHeader)>.<Base64Url(JWSPayload)> )))"  
}
```

Let's see content of the signature envelope for my Notary Project Signature Manifest.
```yaml
# oras blob fetch yoyoociacr.azurecr.io/oci-artifacts@<layers[0].digest> --output signature-envelope.jwt
oras blob fetch yoyoociacr.azurecr.io/oci-artifacts@sha256:cb71e04d24a01cbdabef808730b93e0d642898040158c2528c85194fe4076dff  --output signature-envelope.jwt
✓ Downloaded  application/octet-stream                                                                   2.04/2.04 kB 100.00%     0s
  └─ sha256:cb71e04d24a01cbdabef808730b93e0d642898040158c2528c85194fe4076dff
```

The output signature-envelope.jwt file content:
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

- payload: The data that is integrity protected - e.g. descriptor of the artifact being signed. If we decode the payload by base64, we can get a json content:
    `DecodeBase64(payload) = {"targetArtifact":{"digest":"sha256:f17fbc7debc4eda7456dd3ab0c18c27d50821a9821cfca5607404e654f76e675","mediaType":"application/vnd.oci.image.manifest.v1+json","size":605}}`. The `targetArtifact.digest` is the imageSha of the original image, and the mediaType and size matches to the original image as well. 
- protected, or called `Signed Attributes` or `Protected Headers` are additional metadata apart from the payload. If we decode it by base64, we can also get a json content:
    `DecodeBase64(protected) = {"alg":"PS256","crit":["io.cncf.notary.signingScheme"],"cty":"application/vnd.cncf.notary.payload.v1+json","io.cncf.notary.signingScheme":"notary.x509","io.cncf.notary.signingTime":"2025-02-08T17:41:02+08:00"}`
    in the decoded content, we can see the signing algorithm is PS256, the signing time is 2025-02-08T17:41:02+08:00.
- header, or called `Unsigned Attributes` or `Unprotected Headers` and those metadata which will not be included in the sign process. In the example, there is one requied filed `x5c` which should contain the content of `"x5c": ["<Base64(DER(leafCert))>", "<Base64(DER(intermediateCACert))>", "<Base64(DER(rootCert))>"]`.
- signature: the result of signature which equal to `Base64Url( sign( ASCII( <Base64Url(ProtectedHeader)>.<Base64Url(JWSPayload)> )))`. Now I can answer the quesstion `[1] If the image remains the same, where is the signature?` and `[4] Which fields will be signed.` This field is the signature which is in the Signature Envelope. And the field of `payload` and `protected` will be signed.

- annotations: It is being used to store information about the signature.
  - `io.cncf.notary.x509chain.thumbprint#S256`: A REQUIRED annotation whose value contains the list of SHA-256 fingerprints of signing certificate and certificate chain (including root) used for signature generation. In my example, it is the `yoyo-duan.io.crt`. The list of fingerprints is present as a JSON array string, corresponding to ordered certificates in Certificate Chain unsigned attribute in the signature envelope. The annotation name contains the hash algorithm as a suffix (#S256) and can be extended to support other hashing algorithms in future.

## 4. Verify the signed image
### 4.1 Create a trust policy
To verify the container image, configure the trust policy to specify trusted identities that sign the artifacts, and level of signature verification to use.

In the section [## 2. Generate a test key and self-signed certificate], I mentioned when verifying the signature of an image, we need to specify which named store, or cert, to be used. And it is specified in the trust policy.
