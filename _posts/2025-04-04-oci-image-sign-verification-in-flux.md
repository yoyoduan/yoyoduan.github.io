---
title: OCI Image Signature Verification in FluxV2
date: 2025-04-04 17:57:00 +0800
description: The blog is to describe what should be configured when using FluxV2 to valicate the signature of the OCI image.
categories: [Blogging, OCI]
tags: [oci-image, signature, notation, flux]
media_subpath: /assets/img/oci-image/
---

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
