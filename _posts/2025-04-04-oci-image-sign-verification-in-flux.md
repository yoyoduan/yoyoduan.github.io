---
title: OCI Image Signature Verification in FluxV2
date: 2025-04-04 17:57:00 +0800
description: The blog is to describe how to configure Flux resource to enable signature verification of OCI image using Notation.
categories: [Blogging, OCI]
tags: [oci-image, signature, notation, flux]
media_subpath: /assets/img/oci-image/
---

## Introduction
Flux enables continuous deployment of Kubernetes resources from sources like OCI images[^1]. To ensure only trusted images are deployed, Flux supports signature verification. In this blog, I’ll walk through how to configure Flux resource `OCIRepository` to verify OCI image signatures using Notation.

## Tools & Setup
To follow along with this guide, you'll need:
1. **Docker** – Installed and running.
2. **A signed OCI image in a container registry** -  If you're unfamiliar with how to sign an OCI image, check out my other blog post: [OCI Image Sign and Verification Deep Dive]({% post_url 2025-02-21-oci-image-sign-and-verification-deep-dive %}).
    You can verify the signature with the following command:
    ```powershell
    notation ls yoyoociacr.azurecr.io/oci-artifacts:v1.0
    ```
    Sample output:
    ```text
    yoyoociacr.azurecr.io/oci-artifacts@sha256:e8dc5898b69f8b3786055325edbff66050f21e91fbed5db3d2e8147939fca213
    └── application/vnd.cncf.notary.signature
        └── sha256:b0965724d993c0bfe4149226d6d509ec7d260de78dc4431769b3bbfc72c0feac
    ```
    ![signed OCI image](signed-oci-image.png)

3. **A Kubernetes Cluster with Flux installed**
  ![AKS cluster with Flux extension](aks-cluster-with-flux.png)
    <details>
    <summary>Click to expand the steps to setup Flux on an Azure Kubernetes(AKS) cluster.</summary>
    <pre>
    a. Enable the Flux Extension on the AKS Cluster
    Run the following command to install the Flux extension on your cluster. This will deploy all required controllers (e.g., source-controller, kustomize-controller):
    ```
    $RESOURCE_GROPU = "aks-cluster"
    $CLUSTER_NAME = "yoyo-aks-cluster"
    az k8s-extension create \
      --name flux \
      --cluster-type managedClusters \
      --cluster-name $CLUSTER_NAME \
      --resource-group $RESOURCE_GROPU \
      --extension-type microsoft.flux \
      --scope cluster
    ```

    b. Configure Workload Identity for Flux Source Controller
    If your signed OCI image is stored in Azure Container Registry (ACR), you'll need to:
    - Create a User Assigned Managed Identity
    - Grant it pull access to the ACR
    - Bind it to the Flux source-controller using Azure Workload Identity

    Step 1: Enable Workload Identity on AKS
    Check if OIDC issuer is already enabled:
    ```
    az aks show -n $CLUSTER_NAME -g $RESOURCE_GROPU --query "oidcIssuerProfile.issuerUrl" -o tsv
    ```
    If nothing is returned, enable the feature:
    ```
    az aks update \
      -n $CLUSTER_NAME \
      -g $RESOURCE_GROPU \
      --enable-oidc-issuer \
      --enable-workload-identity
    ```

    Step 2: Create a User Assigned Managed Identity (MSI)
    ```
    $MSI = "flux-source-controller-msi"
    az identity create \
      --name $MSI \
      --resource-group $RESOURCE_GROPU \
      --location eastus
    ```

    Retrieve the client ID:
    ```
    $CLIENT_ID= az identity show --name $MSI --resource-group $RESOURCE_GROPU --query "clientId" -o tsv
    ```

    Step 3: Grant ACR Pull Access to the MSI
    ```
    $ACR = yoyoociacr
    $SCOPE = az acr show --name $ACR --query id --output tsv

    az role assignment create \
      --assignee $CLIENT_ID \
      --role AcrPull \
      --scope $SCOPE
    ```

    Step 4: Bind MSI to Flux Source Controller via Federated Credential
    ```
    $ISSUER_URL=az aks show \
      -n yoyo-aks-cluster \
      -g aks-cluster \
      --query "oidcIssuerProfile.issuerUrl" -o tsv

    az identity federated-credential create \
      --name flux-source-controller-binding \
      --identity-name $MSI \
      --resource-group $RESOURCE_GROUP \
      --issuer $ISSUER_URL \
      --subject system:serviceaccount:flux-system:source-controller \
      --audience api://AzureADTokenExchange
    ```

    Step 5: Patch Flux Source Controller with Workload Identity
    Patch the ServiceAccount:
    ```
    kubectl patch serviceaccount source-controller -n flux-system \
      --patch-file source-controller-patch-service-account.yaml \
      --type merge
    # source-controller-patch-service-account.yaml:
    # metadata:
    #   annotations:
    #     azure.workload.identity/client-id: <REPLACE_WITH_CLIENT_ID>
    #   labels:
    #     azure.workload.identity/use: "true"
    ```
    Then, patch the Deployment:
    ```
    kubectl patch deployment source-controller -n flux-system \
      --patch-file source-controller-patch-deployment.yaml \
      --type merge
    # metadata:
    #   labels:
    #     azure.workload.identity/use: "true"
    # spec:
    #   template:
    #     metadata:
    #       labels:
    #         azure.workload.identity/use: "true"
    ```

## Flux OCI Image Signature Verification
The process of verifying signatures is largely consistent across different signing methods. Once you have a signed OCI image, the core task is to obtain the corresponding public certificate (that pairs with the private key used for signing) and verify the image with it. Thus, the essence of signature verification lies in determining and providing the correct public certificate.

With Notation, this is typically done using a trust store and a trust policy. For a detailed explanation, refer to [OCI Image Signature Verification Steps](https://yoyoduan.github.io/posts/oci-image-sign-and-verification-deep-dive/#oci-image-signuatre-verification-steps-for-users).

However, when using Notation with Flux, things are slightly different — there’s no explicit "trust store." So, how does Flux determine which certificates to use?

The good news: in Flux, this is more straightforward. You embed everything needed (policy and certs) into a Kubernetes `Secret` and reference it in your `OCIRepository`.

Here’s an example:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: oci-artifacts-flux-config
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: oci-artifacts
  namespace: oci-artifacts-flux-config
spec:
  interval: 5m0s
  provider: azure
  ref:
    digest: "sha256:e8dc5898b69f8b3786055325edbff66050f21e91fbed5db3d2e8147939fca213"
  timeout: 60s
  url: oci://yoyoociacr.azurecr.io/oci-artifacts 
  verify:               # an optional field to enable the verification 
    provider: notation  #  to specify the verification provider
    secretRef:
      name: notation-config # to specify a reference to a Secret in the same namespace as the OCIRepository
---
apiVersion: v1
kind: Secret
metadata:
  name: notation-config
  namespace: oci-artifacts-flux-config
type: Opaque
data:
  # <BASE64 of the trust policy> 
  trustpolicy.json: ewogICAgInZlcnNpb24iOiAiMS4wIiwKICAgICJ0cnVzdFBvbGljaWVzIjogWwogICAgICAgIHsKICAgICAgICAgICAgIm5hbWUiOiAic3VwcGx5Y2hhaW4iLAogICAgICAgICAgICAicmVnaXN0cnlTY29wZXMiOiBbICJ5b3lvb2NpYWNyLmF6dXJlY3IuaW8vb2NpLWFydGlmYWN0cyIgXSwKICAgICAgICAgICAgInNpZ25hdHVyZVZlcmlmaWNhdGlvbiI6IHsKICAgICAgICAgICAgICAgICJsZXZlbCIgOiAic3RyaWN0IiAKICAgICAgICAgICAgfSwKICAgICAgICAgICAgInRydXN0U3RvcmVzIjogWyJjYTpub3QtZXhpc3RpbmciXSwKICAgICAgICAgICAgInRydXN0ZWRJZGVudGl0aWVzIjogWyAiKiIgXQogICAgICAgIH0KICAgIF0KfQ==
  certificate1.crt: <BASE64 of a .crt cert>
  certificate2.pem: <BASE64 of a .pem cert>
```

### The OCIRepository
The `OCIRepository` resource defines two fields under `.spec.verify` for enabling signature verification using Notation:

- `.provider` – The name of the signature verification provider. In this case, we use "notation".
- `.secretRef.name` – A reference to a Kubernetes Secret in the same namespace, which contains the trust policy and the public certificates used to verify the OCI image.

### The Referenced Secret
The `.data` field of the referenced `Secret` includes:
1. **Certificates** (`.crt` / `.pem` files) – These are Base64-encoded public certificates used to verify the image's signature. You can include multiple certificates.
    - Their keys (names) can be arbitrary, but they must end with `.crt` or `.pem` to be recognized as certificate files.
    - Verification will succeed if any signature on the image is valid against any of the provided certs.
2. `trustpolicy.json` – The trust policy configuration, also Base64-encoded.
    - The key name `trustpolicy.json` is required and must not be changed.
    - The policy structure mirrors that of standard Notation, with one key difference: the trustStores field.

Here’s what the decoded example trust policy looks like:
```json
{
  "version": "1.0",
  "trustPolicies": [
    {
      "name": "supplychain",
      "registryScopes": [ "yoyoociacr.azurecr.io/oci-artifacts" ],
      "signatureVerification": {
        "level": "strict"
      },
      "trustStores": ["ca:not-existing"],
      "trustedIdentities": ["*"]
    }
  ]
}
```
- `trustStores` field: Although Flux does not support trust stores, this field must still contain at least one element for the policy to be valid. The value doesn’t need to point to an actual store — it just needs to follow the format `<storeType>:<storeName>`, like `ca:not-existing`.
- The rest of the policy (e.g., `trustedIdentities`, `signatureVerification.level`) works the same as in native Notation.

### Verification
Once the certificates and `trustpolicy.json` are correctly referenced by the `OCIRepository` resource, Flux is able to verify the signature of the OCI image. If the verification succeeds, you’ll see a `SourceVerified` condition with status `True` in the resource’s status.

Here’s an example output:
```bash
kubectl describe ocirepository -n oci-artifacts-flux-config

Name:         oci-artifacts
Namespace:    oci-artifacts-flux-config
# ...
Status:
  Conditions:
    # ...
    Last Transition Time:  2025-04-12T06:50:08Z
    Message:               verified signature of revision sha256:e8dc5898b69f8b3786055325edbff66050f21e91fbed5db3d2e8147939fca213
    Observed Generation:   1
    Reason:                Succeeded
    Status:                True
    Type:                  SourceVerified
Events:
  Type    Reason       Age   From               Message
  ----    ------       ----  ----               -------
  Normal  NewArtifact  19s   source-controller  stored artifact with revision 'sha256:e8dc5898b69f8b3786055325edbff66050f21e91fbed5db3d2e8147939fca213' from 'oci://yoyoociacr.azurecr.io/oci-artifacts'
```
This indicates that the image signature was successfully verified before being pulled and stored by the source controller.

### Why is there no explicit trust store in Flux's Notation integration?
You might wonder why Flux doesn't use the Notation trust store like the standard Notation CLI does. Honestly, I had the same question—and the answer lies in the Flux implementation itself. Flux doesn't load a trust store from a file path. Instead, it reads the certificates directly from the Kubernetes Secret and passes them to the Notation verifier in memory.

If you're curious and want to dig into the code, here's the flow that shows how Flux bypasses the traditional trust store:
1. [NotationVerifier.Verify](https://github.com/JasonTheDeveloper/source-controller/blob/553945ab8e4f6f8db23abe275d0c025c934c171d/internal/oci/notation/notation.go#L242) – This is where Flux calls into the Notation library.
2. -> [notation.Verify](https://github.com/notaryproject/notation-go/blob/main/notation.go#L550) – Delegates to the verifier.
3. -> [verifier.Verify](https://github.com/notaryproject/notation-go/blob/main/verifier/verifier.go#L376) – Starts the signature verification process.
4. -> [processSignature](https://github.com/notaryproject/notation-go/blob/main/verifier/verifier.go#L475)  – The actual signature is processed here.
5. -> [loadX509TSATrustStores](https://github.com/notaryproject/notation-go/blob/3bd0ac92b2bad47e477723bdb16a968a089738ae/verifier/helpers.go#L162)  – Normally loads trust stores, but in Flux’s case, this step is essentially bypassed since trust stores are not configured from file-based storage.
6. -> [GetCertificates](https://github.com/JasonTheDeveloper/source-controller/blob/553945ab8e4f6f8db23abe275d0c025c934c171d/internal/oci/notation/notation.go#L142)

So in summary: Flux intentionally skips file-based trust stores and instead injects certs directly via the Secret. That’s why the trustStores field in the policy must exist syntactically (e.g., `["ca:dummy"]`), but its content is never actually used during verification.

## Summary
In this blog, I showed how to configure an `OCIRepository` resource in Flux to enable signature verification using Notation. Most settings align with standard Notation usage, but there's a key difference: Flux does not use a trust store. Instead, the certificates used for verification are defined directly in the referenced Secret. Because of this, the trust policy must be adjusted slightly to satisfy validation, even though the trust store itself is unused.

## References
[^1]: Flux introduction. Available at: [flux-documentation](https://fluxcd.io/flux/).
