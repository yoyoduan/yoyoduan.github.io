---
title: OCI Image Signature Verification in FluxV2
date: 2025-04-04 17:57:00 +0800
description: The blog is to describe what should be configured when using FluxV2 to valicate the signature of the OCI image.
categories: [Blogging, OCI]
tags: [oci-image, signature, notation, flux]
media_subpath: /assets/img/oci-image/
---

## Introduction
Flux enables continuous deployment of Kubernetes resources from sources like OCI images[^1]. To ensure only trusted images are deployed, Flux supports signature verification. In this blog, I’ll walk through how to configure Flux resource `OCIRepository` to verify OCI image signatures using Notation.

## Tools & Setup
To follow along with this guide, you'll need:
1. **Docker** – Installed and running.
2. **A Kubernetes Cluster with Flux installed**
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

    b. If your signed OCI image is saved in an Azure Container Registry, you should grant ImagePull access to an User Assigned Identity(MSI) and then bind the MSI to the OCI source controller.
    
    Firstly, enable the Azure Workload Identity feature for the target AKS cluster
    ```
    # Check if the Azure Workload Identity feature is enabled. 
    az aks show -n yoyo-aks-cluster -g aks-cluster --query "oidcIssuerProfile.issuerUrl" -o tsv

    # If it returns a URL, you’re good. If not, you need to enable OIDC and workload identity:
    az aks update -n yoyo-aks-cluster -g aks-cluster --enable-oidc-issuer --enable-workload-identity
    ```

    Then create a MSI and grant the the target ACR ImagePull access to this MSI
    ```
    az identity create --name flux-source-controller-msi --resource-group aks-cluster --location eastus

    $CLIENT_ID = az identity show --name flux-source-controller-msi --resource-group aks-cluster --query "clientId" -o tsv
    ```

    Next, grant the target ACR ImagePull access to this MSI to the AKS cluster scope:
    ```
    $SCOPE = az acr show --name yoyoociacr --query id --output tsv
    az role assignment create --assignee $CLIENT_ID --role AcrPull --scope $SCOPE
    ```

    Now, the MSI must be federated with the AKS OIDC provider before usage. The value of `subject` points to the service account of the Flux source controller.
    ```
    $ISSUER_URL = az aks show -n yoyo-aks-cluster -g aks-cluster --query "oidcIssuerProfile.issuerUrl" -o tsv
    az identity federated-credential create --name flux-source-controller-binding --identity-name flux-source-controller-msi --resource-group aks-cluster --issuer $ISSUER_URL --subject system:serviceaccount:flux-system:source-controller --audience api://AzureADTokenExchange
    ```

    Finally, patch MSI as workload identity to the Flux source controller's service account and deployment:
    ```
    kubectl patch serviceaccount source-controller -n flux-system --patch-file source-contoller-patch-service-account.yaml --type merge
    # source-contoller-patch-service-account.yaml
    # metadata:
    #   annotations:
    #     azure.workload.identity/client-id: # replace the $CLIENT_ID of the MSI in this field
    #   labels:
    #     azure.workload.identity/use: "true"

    kubectl patch deployment source-controller -n flux-system --patch-file source-contoller-patch-deployment.yaml --type merge
    # source-contoller-patch-deployment.yaml
    # metadata:
    #   labels:
    #     azure.workload.identity/use: "true"
    # spec:
    #   template:
    #     metadata:
    #       labels:
    #         azure.workload.identity/use: "true"
    ```
  ![AKS cluster with Flux extension](aks-cluster-with-flux.png)

1. **A signed OCI image  in a container registry** -  If you're unfamiliar with how to sign an OCI image, check out my other blog post: [OCI Image Sign and Verification Deep Dive]({% post_url 2025-02-21-oci-image-sign-and-verification-deep-dive %}).
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

## References
[^1]:Flux introduction. Available at: [flux-documentation](https://fluxcd.io/flux/).

# Trust Stores in the Flux
No trust store needed when verification. Instead, 
1. Sig of supporting notation to verify the signature: https://github.com/fluxcd/source-controller/issues/1072
2. Flux OCI code of using notation: [func GetCertificates](https://github.com/JasonTheDeveloper/source-controller/blob/553945ab8e4f6f8db23abe275d0c025c934c171d/internal/oci/notation/notation.go#L142)
   [NotationVerifier.Verify](https://github.com/JasonTheDeveloper/source-controller/blob/553945ab8e4f6f8db23abe275d0c025c934c171d/internal/oci/notation/notation.go#L242)
   The function directly using all the certs defined in the secret's spec as the certs to be used to verify the signature of OCI images. It means no trust store is needed and it doesn't matter what the the trustStores field in the trustPolicy is defined. The trustStores filed is not even used.
   **TODO: need to verify this point on the real k8s clusters**

3. The function `GetCertificates` is referred when verifying:
   [NotationVerifier.Verify](https://github.com/JasonTheDeveloper/source-controller/blob/553945ab8e4f6f8db23abe275d0c025c934c171d/internal/oci/notation/notation.go#L242)
   -> [notation.Verify](https://github.com/notaryproject/notation-go/blob/main/notation.go#L550)
   -> [verifier.Verify](https://github.com/notaryproject/notation-go/blob/main/verifier/verifier.go#L376)
   -> [processSignature](https://github.com/notaryproject/notation-go/blob/main/verifier/verifier.go#L475)
   -> [loadX509TSATrustStores](https://github.com/notaryproject/notation-go/blob/3bd0ac92b2bad47e477723bdb16a968a089738ae/verifier/helpers.go#L162)
   -> GetCertificates

# No centralised trust store needed
It should be stored under the same namespace of the ociRepository resource: https://fluxcd.io/flux/components/source/ocirepositories/#verification
