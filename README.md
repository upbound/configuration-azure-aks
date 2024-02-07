# Azure AKS Configuration


This repository contains a [Crossplane configuration](https://docs.crossplane.io/latest/concepts/packages/#configuration-packages), tailored for users establishing their initial control plane with [Upbound](https://cloud.upbound.io). This configuration deploys fully managed [Azure AKS](https://azure.microsoft.com/en-us/products/kubernetes-service) instances.

## Overview

The core components of a custom API in [Crossplane](https://docs.crossplane.io/latest/getting-started/introduction/) include:

- **CompositeResourceDefinition (XRD):** Defines the API's structure.
- **Composition(s):** Implements the API by orchestrating a set of Crossplane managed resources.

In this specific configuration, the AKS API contains:

- **an [AKS](/apis/definition.yaml) custom resource type.**
- **Composition of the AKS resources:** Configured in [/apis/composition.yaml](/apis/composition.yaml), it provisions an [] and resources in the `upbound-system` namespace.

This repository contains an Composite Resource (XR) file.

## Deployment

```shell
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: configuration-azure-aks
spec:
  package: xpkg.upbound.io/upbound/configuration-azure-aks:v0.3.0
```

## Next steps

This repository serves as a foundational step. To enhance your control plane, consider:

1. create new API definitions in this same repo
2. editing the existing API definition to your needs


Upbound will automatically detect the commits you make in your repo and build the configuration package for you. To learn more about how to build APIs for your managed control planes in Upbound, read the guide on Upbound's docs.
