# Crossplane v2 Migration Plan

**Generated**: 2026-01-11
**Project**: configuration-azure-aks
**Current Version**: v1 (cluster-scoped)
**Target Version**: v2 (namespaced)

## Migration Overview

**Impact Summary:**
- XRDs to update: 1 (XAKS → AKS)
- Functions to update: 1 (xaks - requires connection secret rearchitecture)
- Compositions to update: 1
- Tests to update: 2 (1 composition test + 1 E2E test)
- Examples to update: 2
- Dependencies to update: 4 (3 providers + 1 configuration)
- Total estimated tasks: ~85

**Resources affected:**
- `XAKS` → `AKS` (apis/xaks/)

**Breaking changes detected:**
1. **Connection secrets require manual Secret composition** (CRITICAL - most complex change)
2. Provider imports must change: `azure` → `azurem`, `helm` → `helmm`, `kubernetes` → `kubernetesm`
3. XRD API version must update to v2 with namespace scope
4. Kind rename: `XAKS` → `AKS`
5. `managementPolicies` replaces `deletionPolicy`
6. `providerConfigRef` needs explicit `kind` field
7. Namespace removal from secret references
8. `connectionSecretKeys` removal from XRD
9. `writeConnectionSecretToRef` not supported in v2 XRs
10. Major dependency updates (breaking changes in all providers and configuration)

**Complexity**: **HIGH**

**Critical Items Requiring Skill Assistance:**
- Connection secret rearchitecture in xaks function → **Use `author-composition-kcl` skill**
- Manual Secret composition for kubeconfig → **Use `author-composition-kcl` skill**
- Provider API group migrations (azure → azurem) → **Use `author-composition-kcl` skill**

---

## Phase 1: Pre-Migration Preparation

### 1.1 Backup Current State
- [ ] Create git branch: `git checkout -b migrate-to-v2`
- [ ] Verify branch: `git branch --show-current`

### 1.2 Update Dependencies

**File**: `upbound.yaml`

- [ ] Update API version to v2alpha1:
  ```yaml
  # Change from:
  apiVersion: meta.dev.upbound.io/v1alpha1

  # To:
  apiVersion: meta.dev.upbound.io/v2alpha1
  ```

- [ ] Update dependencies to support namespaced resources:

**PROVIDER dependencies:**

- [ ] Update `provider-azure-containerservice` from v1 to v2.0.0+
  - Current: v1 (resolves to v1.7.0) - 0 namespaced resources
  - Target: v2.3.0 (latest) - 4 namespaced resources (KubernetesCluster, etc.)
  - Verified: https://marketplace.upbound.io/providers/upbound/provider-azure-containerservice/v2.3.0#managedResources
  - **BREAKING CHANGE**: API groups change from `containerservice.azure.upbound.io` → `containerservice.azure.m.upbound.io`

  ```yaml
  # Change from:
  - provider: xpkg.upbound.io/upbound/provider-azure-containerservice
    version: "v1"

  # To:
  - provider: xpkg.upbound.io/upbound/provider-azure-containerservice
    version: ">=v2.0.0"
  ```

- [ ] Update `provider-helm` from v0 to v1.0.0+
  - Current: v0 - 0 namespaced resources
  - Target: v1.0.6 (latest) - 3 namespaced resources (ProviderConfig, Release)
  - Verified: https://marketplace.upbound.io/providers/upbound/provider-helm/v1.0.6#managedResources
  - **BREAKING CHANGE**: API groups change from `helm.crossplane.io` → `helm.m.crossplane.io`

  ```yaml
  # Change from:
  - provider: xpkg.upbound.io/upbound/provider-helm
    version: "v0"

  # To:
  - provider: xpkg.upbound.io/upbound/provider-helm
    version: ">=v1.0.0"
  ```

- [x] `provider-kubernetes` v1.2.0 - Already supports namespaced resources ✅
  - Namespace scoped resources: 5 (Object, ProviderConfig, etc.)
  - Verified: https://marketplace.upbound.io/providers/upbound/provider-kubernetes/v1.2.0#managedResources
  - API groups already use namespaced format: `kubernetes.m.crossplane.io`
  - **No update needed**

**CONFIGURATION dependencies:**

- [ ] Update `configuration-azure-network` from v0.18.0 to v2.0.0
  - Current: v0.18.0 - v1 XRD (cluster-scoped XNetwork)
  - Target: v2.0.0 (latest) - v2 XRD (namespaced Network)
  - Verified: https://raw.githubusercontent.com/upbound/configuration-azure-network/v2.0.0/apis/networks/definition.yaml
  - **BREAKING CHANGES**:
    - XR kind changes: `XNetwork` → `Network`
    - API version: v1 → v2
    - Scope: Cluster → Namespaced
    - Directory renamed: `apis/xnetworks/` → `apis/networks/`

  ```yaml
  # Change from:
  - configuration: xpkg.upbound.io/upbound/configuration-azure-network
    version: "v0.18.0"

  # To:
  - configuration: xpkg.upbound.io/upbound/configuration-azure-network
    version: ">=v2.0.0"
  ```

- [ ] Add k8s API dependency for manual Secret composition:
  ```yaml
  spec:
    apiDependencies:
    - k8s:
        version: v1.33.0
      type: k8s
    dependsOn:
    # ... existing dependencies
  ```

- [ ] Run dependency update: `up dep update-cache`
- [ ] Build project to generate v2 models: `up project build`
- [ ] Verify models generated:
  ```bash
  ls -la .up/kcl/models/io/upbound/azurem/containerservice/
  ls -la .up/kcl/models/io/crossplane/helmm/
  ls -la .up/kcl/models/io/crossplane/kubernetesm/
  ls -la .up/kcl/models/io/k8s/api/core/v1/
  ```

---

## Phase 2: XRD Migration

### 2.1 Update XRD: XAKS

**File**: `apis/xaks/definition.yaml`

- [ ] Update API version:
  ```yaml
  # Change from:
  apiVersion: apiextensions.crossplane.io/v1

  # To:
  apiVersion: apiextensions.crossplane.io/v2
  ```

- [ ] Add scope (NEW - required for v2):
  ```yaml
  spec:
    scope: Namespaced  # NEW - makes XRs namespace-scoped
  ```

- [ ] Update metadata.name to remove X-prefix:
  ```yaml
  # Change from:
  metadata:
    name: xaks.azure.platform.upbound.io

  # To:
  metadata:
    name: aks.azure.platform.upbound.io
  ```

- [ ] Update spec.names to remove X-prefix:
  ```yaml
  # Change from:
  spec:
    names:
      kind: XAKS
      plural: xaks

  # To:
  spec:
    names:
      kind: AKS
      plural: aks
  ```

- [ ] Remove `connectionSecretKeys` section (not supported in v2):
  ```yaml
  # Remove this entire section:
  spec:
    connectionSecretKeys:
    - kubeconfig
  ```

  **Note**: Connection secrets now require manual Secret composition in function code (see Phase 3)

- [ ] Replace `deletionPolicy` parameter with `managementPolicies`:
  ```yaml
  # In spec.versions[0].schema.openAPIV3Schema.properties.spec.properties.parameters.properties

  # Change from:
  deletionPolicy:
    description: Delete the external resources when the Claim/XR is deleted. Defaults to Delete
    enum:
    - Delete
    - Orphan
    type: string
    default: Delete

  # To:
  managementPolicies:
    description: "ManagementPolicies for resources. Defaults to [\"*\"] which includes all operations (Create, Observe, Update, Delete, LateInitialize). To orphan resources on deletion, use [\"Create\", \"Observe\", \"Update\", \"LateInitialize\"]."
    type: array
    items:
      type: string
      enum:
        - "*"
        - Create
        - Observe
        - Update
        - Delete
        - LateInitialize
    default: ["*"]
  ```

- [ ] Update required fields in parameters:
  ```yaml
  # Change from:
  required:
  - id
  - region
  - deletionPolicy
  - providerConfigName
  - nodes

  # To:
  required:
  - id
  - region
  - managementPolicies
  - providerConfigName
  - nodes
  ```

**XRD Migration Complete**: XAKS → AKS with v2 API, namespaced scope, and updated schema

---

## Phase 3: Function Code Migration

**🎯 EXECUTION STRATEGY: Use `author-composition-kcl` skill**

**Recommended workflow:**
1. Read the checklist below for the xaks function
2. Use Skill tool: `Skill(skill="control-plane-project:author-composition-kcl")`
3. Tell the skill: "Migrate function xaks from v1 to v2" and reference this checklist
4. The skill will guide you through proper patterns, type safety, and v2 conventions

**Why use the skill instead of manual edits:**
- ✅ Ensures proper KCL syntax and proven patterns
- ✅ Validates type safety with typed models
- ✅ Prevents common v2 migration mistakes (providerConfigRef.kind, managementPolicies, etc.)
- ✅ Interactive guidance on complex changes (connection secrets, optional fields)
- ❌ Manual edits risk missing v2 requirements and introducing subtle bugs

---

### 3.1 Update Function: xaks

**File**: `functions/xaks/main.k`

**🎯 EXECUTE: Use `author-composition-kcl` skill for this function**

**Import changes:**

- [ ] Update Azure provider imports:
  ```kcl
  # Change from:
  import models.io.upbound.azure.containerservice.v1beta2 as azureContainerServicev1beta2

  # To:
  import models.io.upbound.azurem.containerservice.v1beta2 as azureContainerServicev1beta2
  ```

- [ ] Update Kubernetes provider imports:
  ```kcl
  # Change from:
  import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1

  # To:
  import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesv1alpha1
  ```

- [ ] Update Helm provider imports:
  ```kcl
  # Change from:
  import models.io.crossplane.helm.v1beta1 as helmv1beta1

  # To:
  import models.io.crossplane.helmm.v1beta1 as helmv1beta1
  ```

- [ ] Update XR type import:
  ```kcl
  # Change from:
  import models.io.upbound.platform.azure.v1alpha1.xaks

  # To:
  import models.io.upbound.platform.azure.v1alpha1.aks
  ```

- [ ] Add imports for connection secret composition:
  ```kcl
  import base64
  import models.io.k8s.api.core.v1 as corev1
  ```

**Schema updates:**

- [ ] Update ObservedComposedResources schema:
  ```kcl
  # Change from:
  schema ObservedComposedResources:
      dxr: xaks.XAKS
      kubernetesCluster: azureContainerServicev1beta2.KubernetesCluster
      workloadIdentitySettings: kubernetesv1alpha1.Object
      providerConfigHelm: helmv1beta1.ProviderConfig
      providerConfigKubernetes: kubernetesv1alpha1.ProviderConfig
      compositeConnectionDetails: CompositeConnectionDetails

  # To:
  schema ObservedComposedResources:
      dxr: aks.AKS
      kubernetesCluster: azureContainerServicev1beta2.KubernetesCluster
      workloadIdentitySettings: kubernetesv1alpha1.Object
      providerConfigHelm: helmv1beta1.ProviderConfig
      providerConfigKubernetes: kubernetesv1alpha1.ProviderConfig
      connectionSecret: corev1.Secret  # Changed from CompositeConnectionDetails
  ```

- [ ] Update DefaultSpec schema to use managementPolicies:
  ```kcl
  # Change from:
  schema DefaultSpec:
      deletionPolicy: str
      providerConfigRef: {str:str}
      forProvider: {str:str}

  # To:
  schema DefaultSpec:
      managementPolicies: [str]
      providerConfigRef: {str:str}
      forProvider: {str:str}
  ```

- [ ] Remove CompositeConnectionDetails schema (not needed in v2):
  ```kcl
  # Remove this entire schema:
  schema CompositeConnectionDetails:
      apiVersion: str = "meta.krm.kcl.dev/v1alpha1"
      kind: str = "CompositeConnectionDetails"
      data: {str:str}
  ```

**Parameter initialization updates:**

- [ ] Update XR type references:
  ```kcl
  # Change from:
  oxrParams = xaks.XAKS.spec.parameters {**oxr.spec.parameters}
  oxrSpec = xaks.XAKS.spec {**oxr.spec}

  # To:
  oxrParams = aks.AKS.spec.parameters {**oxr.spec.parameters}
  oxrSpec = aks.AKS.spec {**oxr.spec}
  ```

- [ ] Add observed composed resources helper:
  ```kcl
  # Add after parameter initialization:
  _ocds = option("params").ocds or {}
  ```

**Spec defaults updates:**

- [ ] Update _defaultSpec to use managementPolicies and add kind to providerConfigRef:
  ```kcl
  # Change from:
  _defaultSpec = DefaultSpec {
      deletionPolicy = oxrParams.deletionPolicy or "Delete"
      providerConfigRef = {
          name = oxrParams.providerConfigName or "default"
      }
      forProvider = {
          location = oxrParams.region
      }
  }

  # To:
  _defaultSpec = DefaultSpec {
      managementPolicies = oxrParams.managementPolicies or ["*"]
      providerConfigRef = {
          kind = "ProviderConfig"  # NEW - required in v2
          name = oxrParams.providerConfigName or "default"
      }
      forProvider = {
          location = oxrParams.region
      }
  }
  ```

**Composition updates:**

- [ ] Update dxr composition to use AKS type:
  ```kcl
  # Change from:
  dxr = xaks.XAKS {
      **dxr
      spec.parameters = {
          id = oxrSpec.parameters.id
          nodes = oxrSpec.parameters.nodes
          region = oxrSpec.parameters.region
      }
      status = {
          aks = {
              oidcUrl = ocds?.kubernetesCluster?.status?.atProvider?.oidcIssuerUrl
          }
      }
  }

  # To:
  dxr = aks.AKS {
      **dxr
      spec.parameters = {
          id = oxrSpec.parameters.id
          nodes = oxrSpec.parameters.nodes
          region = oxrSpec.parameters.region
      }
      status = {
          aks = {
              oidcUrl = _ocds?.kubernetesCluster?.Resource?.status?.atProvider?.oidcIssuerUrl
          }
      }
  }
  ```

- [ ] Update kubernetesCluster to remove namespace from secret ref:
  ```kcl
  # In kubernetesCluster spec, change:
  writeConnectionSecretToRef = {
      name = "{}-akscluster".format(oxrMeta.uid)
      namespace = oxrSpec.writeConnectionSecretToRef.namespace  # Remove this line
  }

  # To:
  writeConnectionSecretToRef = {
      name = "{}-akscluster".format(oxrMeta.uid)
      # namespace is inferred from XR namespace in v2
  }
  ```

- [ ] Update workloadIdentitySettings to use managementPolicies:
  ```kcl
  # Change from:
  spec = {
      deletionPolicy = "Orphan"
      forProvider = { ... }
      providerConfigRef = {
          name = oxrSpec.parameters.id
      }
  }

  # To:
  spec = {
      managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]  # Orphan equivalent
      forProvider = { ... }
      providerConfigRef = {
          kind = "ProviderConfig"  # NEW
          name = oxrSpec.parameters.id
      }
  }
  ```

- [ ] Update providerConfigHelm to remove namespace from secret ref:
  ```kcl
  # In spec.credentials.secretRef, change:
  secretRef = {
      key = "kubeconfig"
      name = "{}-akscluster".format(oxrMeta.uid)
      namespace = oxrSpec.writeConnectionSecretToRef.namespace  # Remove this
  }

  # To:
  secretRef = {
      key = "kubeconfig"
      name = "{}-akscluster".format(oxrMeta.uid)
      # namespace inferred from ProviderConfig namespace in v2
  }
  ```

- [ ] Update providerConfigKubernetes to remove namespace from secret ref:
  ```kcl
  # Same change as providerConfigHelm above
  secretRef = {
      key = "kubeconfig"
      name = "{}-akscluster".format(oxrMeta.uid)
      # Remove: namespace = oxrSpec.writeConnectionSecretToRef.namespace
  }
  ```

- [ ] **CRITICAL: Replace compositeConnectionDetails with manual Secret composition**

  ```kcl
  # Remove the old compositeConnectionDetails section:
  # compositeConnectionDetails = CompositeConnectionDetails { ... }

  # Add new connectionSecret section:
  connectionSecret = corev1.Secret {
      metadata = {
          name = "{}-connection".format(oxrMeta.name)
          namespace = oxrMeta.namespace
          annotations = {
              "krm.kcl.dev/composition-resource-name" = "connection-secret"
          }
          labels = {
              "crossplane.io/composite" = oxrMeta.name
          }
      }
      type = "connection.crossplane.io/v1alpha1"
      if "kubernetesCluster" in _ocds:
          data = {
              # kubeconfig is already base64-encoded from kubernetesCluster connection secret
              kubeconfig = _ocds.kubernetesCluster.ConnectionDetails?.kubeconfig or ""
          }
      else:
          data = {}
  }
  ```

  **Notes on connection secret migration:**
  - XRs in v2 no longer support built-in `writeConnectionSecretToRef`
  - Must manually compose Kubernetes Secret resources
  - The kubeconfig from KubernetesCluster's connection secret is already base64-encoded
  - Secret type `connection.crossplane.io/v1alpha1` is the standard for connection secrets
  - Namespace is inferred from XR namespace (oxrMeta.namespace)

**Function Migration Complete**: All imports updated, managementPolicies implemented, connection secrets manually composed

---

## Phase 4: Composition Updates

### 4.1 Update Composition: xaks.azure.platform.upbound.io

**File**: `apis/xaks/composition.yaml`

- [ ] Update compositeTypeRef.kind to remove X-prefix:
  ```yaml
  # Change from:
  spec:
    compositeTypeRef:
      apiVersion: azure.platform.upbound.io/v1alpha1
      kind: XAKS

  # To:
  spec:
    compositeTypeRef:
      apiVersion: azure.platform.upbound.io/v1alpha1
      kind: AKS
  ```

- [ ] Update metadata.name to match new XRD name:
  ```yaml
  # Change from:
  metadata:
    name: xaks.azure.platform.upbound.io

  # To:
  metadata:
    name: aks.azure.platform.upbound.io
  ```

**Composition Migration Complete**: Kind updated to AKS

---

## Phase 5: Example Updates

### 5.1 Update Example: xaks.yaml

**File**: `examples/xaks/xaks.yaml`

- [ ] Update apiVersion to match new group (if changed):
  ```yaml
  # apiVersion stays the same:
  apiVersion: azure.platform.upbound.io/v1alpha1
  ```

- [ ] Update kind to remove X-prefix:
  ```yaml
  # Change from:
  kind: XAKS

  # To:
  kind: AKS
  ```

- [ ] Add namespace to metadata:
  ```yaml
  # Change from:
  metadata:
    name: configuration-azure-aks

  # To:
  metadata:
    name: configuration-azure-aks
    namespace: default  # NEW - required for namespaced resources
  ```

- [ ] Remove writeConnectionSecretToRef (not supported in v2 XRs):
  ```yaml
  # Remove this entire section:
  spec:
    writeConnectionSecretToRef:
      name: configuration-azure-aks-kubeconfig
      namespace: upbound-system
  ```

  **Note**: Connection secret is now created automatically by the function (see Phase 3)
  - Secret will be named: `{xr-name}-connection` (e.g., `configuration-azure-aks-connection`)
  - Secret will be in the same namespace as the XR (`default`)
  - Secret will contain the `kubeconfig` key

- [ ] Update managementPolicies parameter (if using deletionPolicy):
  ```yaml
  # If example had deletionPolicy parameter, change it:
  # (Not present in this example, but add if needed for testing)
  spec:
    parameters:
      managementPolicies: ["*"]  # Or ["Create", "Observe", "Update", "LateInitialize"] for orphan
  ```

### 5.2 Update Example: xnetwork.yaml

**File**: `examples/xaks/xnetwork.yaml`

**Note**: This example uses `XNetwork` from the `configuration-azure-network` dependency, which will change to `Network` in v2.

- [ ] Update kind (from configuration-azure-network v2):
  ```yaml
  # Change from:
  kind: XNetwork

  # To:
  kind: Network
  ```

- [ ] Add namespace to metadata:
  ```yaml
  # Change from:
  metadata:
    name: configuration-azure-aks

  # To:
  metadata:
    name: configuration-azure-aks
    namespace: default  # NEW - required for namespaced resources
  ```

- [ ] Verify apiVersion (should remain the same in configuration-azure-network v2):
  ```yaml
  # Stays the same:
  apiVersion: azure.platform.upbound.io/v1alpha1
  ```

**Examples Migration Complete**: Kinds updated, namespaces added, writeConnectionSecretToRef removed

---

## Phase 6: Test Updates

**🎯 EXECUTION STRATEGY: Use `author-tests-kcl` skill**

**Recommended workflow:**
1. Read the checklists below for specific tests
2. Use Skill tool: `Skill(skill="control-plane-project:author-tests-kcl")`
3. Tell the skill: "Update test [name] for v2 migration" and reference this checklist
4. The skill will ensure proper test structure, correct patterns, and validation

**Why use the skill instead of manual edits:**
- ✅ Ensures correct test structure (imports, XR definitions, assertions)
- ✅ Validates against test checklists automatically
- ✅ Prevents common test mistakes (missing namespace, wrong API versions)
- ✅ Can refactor multiple tests efficiently using the skill's refactoring features
- ❌ Manual edits risk inconsistent test patterns and missing assertions

---

### 6.1 Update Composition Test: test-xaks

**File**: `tests/test-xaks/main.k`

**🎯 EXECUTE: Use `author-tests-kcl` skill for this test**

**Import updates:**

- [ ] Update Azure provider imports:
  ```kcl
  # Change from:
  import models.io.upbound.azure.containerservice.v1beta2 as containerservicev1beta2

  # To:
  import models.io.upbound.azurem.containerservice.v1beta2 as containerservicev1beta2
  ```

- [ ] Update Kubernetes provider imports:
  ```kcl
  # Change from:
  import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1

  # To:
  import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesv1alpha1
  ```

- [ ] Update Helm provider imports:
  ```kcl
  # Change from:
  import models.io.crossplane.helm.v1beta1 as helmv1beta1

  # To:
  import models.io.crossplane.helmm.v1beta1 as helmv1beta1
  ```

- [ ] Update platform imports:
  ```kcl
  # Change from:
  import models.io.upbound.platform.azure.v1alpha1 as upazurev1alpha1

  # To (if needed - keep watching for changes):
  import models.io.upbound.platform.azure.v1alpha1 as upazurev1alpha1
  ```

- [ ] Add k8s core imports for Secret assertions:
  ```kcl
  import models.io.k8s.api.core.v1 as corev1
  ```

**XR updates:**

- [ ] Update XR kind in test assertion:
  ```kcl
  # Change from:
  assertResources: [
      upazurev1alpha1.XAKS{

  # To:
  assertResources: [
      upazurev1alpha1.AKS{
  ```

- [ ] Add namespace to XR metadata:
  ```kcl
  # Change from:
  upazurev1alpha1.AKS{
      metadata = {
          name = "configuration-azure-aks"
      }

  # To:
  upazurev1alpha1.AKS{
      metadata = {
          name = "configuration-azure-aks"
          namespace = "default"  # NEW
      }
  ```

- [ ] Remove writeConnectionSecretToRef from XR assertion:
  ```kcl
  # Remove this from XR spec:
  spec = {
      parameters = { ... }
      # Remove:
      writeConnectionSecretToRef = {
          name = "configuration-azure-aks-kubeconfig"
          namespace = "upbound-system"
      }
  }
  ```

**Managed resource assertion updates:**

- [ ] Update KubernetesCluster assertions:
  ```kcl
  containerservicev1beta2.KubernetesCluster{
      metadata = {
          annotations = {
              "crossplane.io/composition-resource-name" = "kubernetesCluster"
          }
          generateName = "configuration-azure-aks-"
          labels = {
              "crossplane.io/composite" = "configuration-azure-aks"
          }
          name = "configuration-azure-aks-aks"
          ownerReferences = [
              {
                  apiVersion = "azure.platform.upbound.io/v1alpha1"
                  blockOwnerDeletion = True
                  controller = True
                  kind = "AKS"  # Changed from XAKS
                  name = "configuration-azure-aks"
                  uid = ""
              }
          ]
      }
      spec = {
          # Remove deletionPolicy assertion (not present here)
          # Add managementPolicies assertion:
          managementPolicies = ["*"]  # NEW

          # Add providerConfigRef.kind:
          providerConfigRef = {
              kind = "ProviderConfig"  # NEW
              name = "default"
          }

          forProvider = { ... }  # Keep existing

          # Update writeConnectionSecretToRef - remove namespace:
          writeConnectionSecretToRef = {
              name = "Undefined-akscluster"
              # Remove: namespace = "upbound-system"
          }
      }
  }
  ```

- [ ] Update Object (workloadIdentitySettings) assertions:
  ```kcl
  kubernetesv1alpha1.Object{
      metadata = {
          annotations = {
              "crossplane.io/composition-resource-name" = "workloadIdentitySettings"
          }
          labels = {
              "crossplane.io/composite" = "configuration-azure-aks"
          }
          ownerReferences = [
              {
                  apiVersion = "azure.platform.upbound.io/v1alpha1"
                  blockOwnerDeletion = True
                  controller = True
                  kind = "AKS"  # Changed from XAKS
                  name = "configuration-azure-aks"
                  uid = ""
              }
          ]
      }
      spec = {
          # Change deletionPolicy to managementPolicies:
          managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]  # Orphan equivalent

          forProvider = { ... }  # Keep existing

          # Add kind to providerConfigRef:
          providerConfigRef = {
              kind = "ProviderConfig"  # NEW
              name = "configuration-azure-aks"
          }
      }
  }
  ```

- [ ] Update helmv1beta1.ProviderConfig assertions:
  ```kcl
  helmv1beta1.ProviderConfig{
      metadata = {
          annotations = {
              "crossplane.io/composition-resource-name" = "providerConfigHelm"
          }
          labels = {
              "crossplane.io/composite" = "configuration-azure-aks"
          }
          name = "configuration-azure-aks"
          ownerReferences = [
              {
                  apiVersion = "azure.platform.upbound.io/v1alpha1"
                  blockOwnerDeletion = True
                  controller = True
                  kind = "AKS"  # Changed from XAKS
                  name = "configuration-azure-aks"
                  uid = ""
              }
          ]
      }
      spec = {
          credentials = {
              secretRef = {
                  key = "kubeconfig"
                  name = "Undefined-akscluster"
                  # Remove: namespace = "upbound-system"
              }
              source = "Secret"
          }
      }
  }
  ```

- [ ] Update kubernetesv1alpha1.ProviderConfig assertions:
  ```kcl
  kubernetesv1alpha1.ProviderConfig{
      metadata = {
          # ... same ownerReference kind change as above
          ownerReferences = [
              {
                  kind = "AKS"  # Changed from XAKS
                  # ... rest stays same
              }
          ]
      }
      spec = {
          credentials = {
              secretRef = {
                  key = "kubeconfig"
                  name = "Undefined-akscluster"
                  # Remove: namespace = "upbound-system"
              }
              source = "Secret"
          }
      }
  }
  ```

- [ ] **Add connection Secret assertion (NEW)**:
  ```kcl
  # Add to assertResources list:
  corev1.Secret{
      metadata = {
          name = "configuration-azure-aks-connection"
          namespace = "default"
          annotations = {
              "crossplane.io/composition-resource-name" = "connection-secret"
          }
          labels = {
              "crossplane.io/composite" = "configuration-azure-aks"
          }
      }
      type = "connection.crossplane.io/v1alpha1"
      # Data assertions - can be flexible since values come from observed resources
  }
  ```

### 6.2 Update E2E Test: e2etest-xaks

**File**: `tests/e2etest-xaks/main.k`

**🎯 EXECUTE: Use `author-tests-kcl` skill for this test**

**Import updates:**

- [ ] Update Azure provider imports:
  ```kcl
  # Change from:
  import models.io.upbound.azure.v1beta1 as azurev1beta1

  # To:
  import models.io.upbound.azurem.v1beta1 as azurev1beta1
  ```

- [ ] Update platform imports (if needed):
  ```kcl
  # Should stay the same:
  import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
  ```

**Crossplane configuration:**

- [ ] Pin Crossplane version to v2 (IMPORTANT):
  ```kcl
  # Change from:
  crossplane = {
      autoUpgrade.channel = "Rapid"
      version = "1.18.3-up.1"
  }

  # To:
  crossplane = {
      version = "2.0.2-up.5"  # Pinned to v2
      autoUpgrade.channel = "None"  # Disable auto-upgrade for stability
  }
  ```

**Manifest updates:**

- [ ] Update AKS manifest kind:
  ```kcl
  # Change from:
  manifests = [
      platformazurev1alpha1.XAKS{

  # To:
  manifests = [
      platformazurev1alpha1.AKS{
  ```

- [ ] Add namespace to AKS metadata:
  ```kcl
  platformazurev1alpha1.AKS{
      metadata = {
          name = "configuration-azure-aks"
          namespace = "default"  # NEW
      }
  ```

- [ ] Remove writeConnectionSecretToRef from AKS spec:
  ```kcl
  # Remove:
  spec = {
      parameters = { ... }
      writeConnectionSecretToRef = {
          name = "configuration-azure-aks-kubeconfig"
          namespace = "upbound-system"
      }
  }

  # To:
  spec = {
      parameters = { ... }
      # writeConnectionSecretToRef removed - secret created automatically
  }
  ```

- [ ] Update Network manifest (from configuration-azure-network v2):
  ```kcl
  # Change from:
  platformazurev1alpha1.XNetwork{
      metadata = {
          name = "configuration-azure-aks"
      }

  # To:
  platformazurev1alpha1.Network{
      metadata = {
          name = "configuration-azure-aks"
          namespace = "default"  # NEW
      }
  ```

**Provider configuration updates:**

- [ ] Update ProviderConfig to be namespaced:
  ```kcl
  # Change from:
  extraResources = [
      azurev1beta1.ProviderConfig{
          metadata.name = "default"
          spec = { ... }
      }
  ]

  # To:
  extraResources = [
      azurev1beta1.ProviderConfig{
          metadata = {
              name = "default"
              namespace = "default"  # NEW - ProviderConfig is now namespaced
          }
          spec = { ... }  # Keep existing credentials config
      }
  ]
  ```

**E2E Tests Migration Complete**: All imports updated, Crossplane v2 pinned, namespaces added

---

## Phase 7: File Reorganization

**Current structure is already correct** - files are organized in subdirectories:
```
apis/
  xaks/
    definition.yaml
    composition.yaml
```

**After migration, directory should be renamed to match resource name:**

- [ ] Rename directory to remove X-prefix:
  ```bash
  git mv apis/xaks apis/aks
  ```

- [ ] Update function directory to match:
  ```bash
  git mv functions/xaks functions/aks
  ```

- [ ] Update test directory references:
  ```bash
  git mv tests/test-xaks tests/test-aks
  git mv tests/e2etest-xaks tests/e2etest-aks
  ```

- [ ] Update example directory:
  ```bash
  git mv examples/xaks examples/aks
  ```

**Update all path references:**

- [ ] Update test paths in test files:
  ```kcl
  # In tests/test-aks/main.k:
  # Change:
  compositionPath: "apis/xaks/composition.yaml"
  xrPath: "examples/xaks/xaks.yaml"
  xrdPath: "apis/xaks/definition.yaml"

  # To:
  compositionPath: "apis/aks/composition.yaml"
  xrPath: "examples/aks/aks.yaml"
  xrdPath: "apis/aks/definition.yaml"
  ```

- [ ] Rename example file:
  ```bash
  git mv examples/aks/xaks.yaml examples/aks/aks.yaml
  ```

- [ ] Update any README or documentation references to file paths

**File Reorganization Complete**: All directories and files renamed to remove X-prefix

---

## Phase 8: Verification

**🎯 EXECUTION STRATEGY: Use `verify-configuration` skill**

**Recommended workflow:**
1. After completing Phases 1-7, use Skill tool: `Skill(skill="control-plane-project:verify-configuration")`
2. The skill will automatically:
   - Build the project
   - Run all composition tests
   - Report detailed pass/fail status
   - Offer to run E2E tests (with confirmation)

**Why use the skill instead of manual commands:**
- ✅ Automated build + test execution with proper error reporting
- ✅ Validates project structure and configuration
- ✅ Offers E2E test orchestration with monitoring
- ✅ Generates comprehensive verification reports
- ❌ Manual commands require tracking multiple steps and interpreting raw output

**If you prefer manual verification, follow the checklists below:**

### 8.1 Build and Validate

- [ ] Clean build: `rm -rf .up/ && up project build`
- [ ] Verify build succeeds with no errors
- [ ] Check generated models:
  ```bash
  # Verify Azure provider models (azurem):
  ls -la .up/kcl/models/io/upbound/azurem/containerservice/v1beta2/

  # Verify Helm provider models (helmm):
  ls -la .up/kcl/models/io/crossplane/helmm/v1beta1/

  # Verify Kubernetes provider models (kubernetesm):
  ls -la .up/kcl/models/io/crossplane/kubernetesm/v1alpha1/

  # Verify k8s core models (for Secret):
  ls -la .up/kcl/models/io/k8s/api/core/v1/

  # Verify platform models (AKS type):
  ls -la .up/kcl/models/io/upbound/platform/azure/v1alpha1/
  ```
- [ ] Verify no import errors in build output

### 8.2 Composition Tests

- [ ] Run composition test: `up test run tests/test-aks`
- [ ] Verify test passes
- [ ] Check that all resources are generated correctly:
  - AKS XR (not XAKS)
  - KubernetesCluster with managementPolicies
  - ProviderConfigs with kind field
  - Connection Secret resource
  - No namespace fields in secret refs

### 8.3 Composition Rendering

- [ ] Render composition:
  ```bash
  up composition render \
    --xrd=apis/aks/definition.yaml \
    apis/aks/composition.yaml \
    examples/aks/aks.yaml
  ```
- [ ] Verify output contains namespaced provider resources:
  - Check for `.m.` in apiVersion (e.g., `containerservice.azure.m.upbound.io`)
- [ ] Verify no `deletionPolicy` fields in output (should be `managementPolicies`)
- [ ] Verify `providerConfigRef` includes `kind: ProviderConfig`
- [ ] Verify connection Secret resource present in output:
  ```yaml
  apiVersion: v1
  kind: Secret
  type: connection.crossplane.io/v1alpha1
  ```
- [ ] Verify no `namespace` fields in secret references
- [ ] Verify all resources have namespace: default

### 8.4 E2E Tests (Recommended)

**🎯 EXECUTE: Use `e2e-test-configuration` skill**

**MANDATORY workflow:**
1. After composition tests pass, use Skill tool: `Skill(skill="control-plane-project:e2e-test-configuration")`
2. The skill will:
   - Run E2E tests on Upbound Cloud
   - Monitor progress with stuck detection
   - Provide comprehensive debugging if tests fail
   - Generate detailed test reports

**Manual E2E test (if skill not available):**

- [ ] Run E2E test: `up test run --e2e tests/e2etest-aks`
- [ ] Monitor test progress (can take up to 60 minutes)
- [ ] Verify resources are created successfully in Upbound Cloud control plane
- [ ] Verify Azure resources are provisioned (AKS cluster, VNet, Subnet)
- [ ] Verify connection secret is created with kubeconfig
- [ ] Clean up test resources after validation

### 8.5 Final Validation Checklist

- [ ] All builds succeed without errors
- [ ] All composition tests pass
- [ ] Composition rendering produces correct output
- [ ] E2E tests pass (or issues identified and documented)
- [ ] No v1 API references remain in code
- [ ] All X-prefixed kinds removed
- [ ] All provider imports use namespaced packages (azurem, helmm, kubernetesm)
- [ ] All connection secrets manually composed
- [ ] All managementPolicies correctly implemented
- [ ] All providerConfigRef include kind field
- [ ] No namespace fields in secret references
- [ ] All examples work with namespaced resources

**Verification Complete**: Project successfully migrated to Crossplane v2

---

## Phase 9: Documentation

- [ ] Update README.md:
  - Update API version references (v1 → v2)
  - Add namespace requirements section
  - Document connection secret changes:
    - Connection secrets now created automatically by function
    - Secret name format: `{xr-name}-connection`
    - Secret contains `kubeconfig` key
    - No need for `writeConnectionSecretToRef` in XR spec
  - Update example usage with namespace
  - Update provider dependency versions

- [ ] Update file path references:
  - Update paths from xaks → aks
  - Update composition rendering commands with new paths
  - Update test commands with new paths

- [ ] Document migration notes:
  - List breaking changes from user perspective:
    - XR kind changed: XAKS → AKS
    - XRs must include namespace in metadata
    - Connection secrets renamed: `{uid}-akscluster` → `{name}-connection`
    - Connection secret namespace: same as XR (not configurable)
    - managementPolicies replaces deletionPolicy parameter
  - Document behavioral differences:
    - Resources are now namespace-scoped
    - Connection secrets automatically created (no spec.writeConnectionSecretToRef)
  - Add migration date and version info:
    - Migration date: [date completed]
    - Crossplane version: v2.0.2-up.5+
    - Configuration version: [new version after migration]

- [ ] Update CHANGELOG or release notes:
  - Add breaking changes section
  - Document upgrade path for existing users
  - List new features enabled by v2

- [ ] Update any CI/CD configurations:
  - Update test commands with new paths
  - Update Crossplane version requirements
  - Update provider version constraints

**Documentation Complete**: All docs updated for v2

---

## Migration Checklist Summary

**Total Tasks**: ~85

**By Phase:**
- Phase 1 (Pre-migration): 10 tasks
- Phase 2 (XRDs): 7 tasks
- Phase 3 (Functions): 18 tasks
- Phase 4 (Compositions): 2 tasks
- Phase 5 (Examples): 8 tasks
- Phase 6 (Tests): 28 tasks
- Phase 7 (Reorganization): 6 tasks
- Phase 8 (Verification): 18 tasks
- Phase 9 (Documentation): 8 tasks

**Critical Path Items:**
1. Phase 1.2: Dependency updates (MUST complete before function changes - breaking API changes)
2. Phase 2: XRD API version updates (foundational change - affects all other phases)
3. Phase 3: Function import changes (affects all downstream phases)
4. Phase 3: Connection secret rearchitecture (MOST COMPLEX CHANGE - manual Secret composition)
5. Phase 8: Verification (ensures migration success before release)

**Estimated Complexity by Component:**
- **High Complexity** (requires skill assistance):
  - Function xaks migration (connection secrets, provider imports, managementPolicies)
  - Test updates (many assertion changes)
- **Medium Complexity** (straightforward but tedious):
  - XRD schema updates
  - Dependency updates
  - File reorganization
- **Low Complexity** (simple find-replace):
  - Composition kind updates
  - Example kind updates

**Recommended Execution Order:**
1. Phase 1 (Dependencies) - CRITICAL FIRST STEP
2. Phase 2 (XRDs) - Foundation for everything else
3. Phase 3 (Functions) - Use `author-composition-kcl` skill
4. Phase 4 (Compositions) - Quick updates
5. Phase 5 (Examples) - Quick updates
6. Phase 6 (Tests) - Use `author-tests-kcl` skill
7. Phase 7 (Reorganization) - Cleanup
8. Phase 8 (Verification) - Use `verify-configuration` + `e2e-test-configuration` skills
9. Phase 9 (Documentation) - Final polish

---

## References

- [Crossplane v2 Upgrade Guide](https://docs.crossplane.io/latest/guides/upgrade-to-crossplane-v2/)
- [What's New in Crossplane v2](https://docs.crossplane.io/latest/whats-new/)
- [Upbound DevEx Documentation](https://docs.crossplane.io/)
- [Namespaced Provider Resources](https://docs.crossplane.io/latest/concepts/namespaced-providers/)
- [Connection Secrets in v2](https://docs.crossplane.io/latest/concepts/connection-secrets/)

---

## Dependency Update Summary

### Providers

| Provider | Current | Target | Namespace Support | Breaking Changes |
|----------|---------|--------|-------------------|------------------|
| provider-azure-containerservice | v1 | v2.0.0+ | 0 → 4 resources | API group: `.azure.` → `.azure.m.` |
| provider-helm | v0 | v1.0.0+ | 0 → 3 resources | API group: `.helm.` → `.helm.m.` |
| provider-kubernetes | v1.2.0 | v1.2.0 ✓ | 5 resources | Already namespaced ✓ |

### Configurations

| Configuration | Current | Target | Namespace Support | Breaking Changes |
|---------------|---------|--------|-------------------|------------------|
| configuration-azure-network | v0.18.0 | v2.0.0 | v1 → v2 | Kind: `XNetwork` → `Network`<br>Scope: Cluster → Namespaced<br>Dir: `xnetworks/` → `networks/` |

---

*Migration plan generated by control-plane-project:plan-v2-migration skill*
