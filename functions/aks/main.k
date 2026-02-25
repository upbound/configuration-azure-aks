import models.io.upbound.azurem.containerservice.v1beta1 as azureContainerServicev1beta1
import models.io.upbound.platform.azure.v1alpha1.aks
import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesmv1alpha1
import models.io.crossplane.helmm.v1beta1 as helmmv1beta1

schema DefaultSpec:
    managementPolicies: [str]
    providerConfigRef: {str:str}
    forProvider: {str:str}

# Note: avoid casting the full OXR (e.g. AKS{**oxr}) because the
# auto-generated model types status.conditions as a typed list which is
# incompatible with the generic list Crossplane passes at runtime.
# Instead, keep the raw OXR and cast only the sub-fields we need.
oxr = option("params").oxr
dxr = option("params").dxr
ocds = option("params").ocds
_params = aks.AKS.spec.parameters{**oxr.spec.parameters}

_metadata = lambda name: str -> any {
    {
        annotations = {"krm.kcl.dev/composition-resource-name" = name}
    }
}

_defaultSpec = DefaultSpec {
    managementPolicies = _params.managementPolicies or ["*"]
    providerConfigRef = {
        kind = "ProviderConfig"
        name = _params.providerConfigName or "default"
    }
    forProvider = {}
}

_items = [
    aks.AKS {
        **dxr
        spec.parameters = {
            id = _params.id
            nodes = _params.nodes
            region = _params.region
        }
        status = {
            aks = {
                oidcUrl = ocds?.kubernetesCluster?.Resource?.status?.atProvider?.oidcIssuerUrl
            }
        }
    }
    azureContainerServicev1beta1.KubernetesCluster {
        metadata = {
            **_metadata("kubernetesCluster")
            name = "{}-aks".format(_params.id)
        }
        spec = {
            **_defaultSpec
            forProvider = {
                defaultNodePool = {
                    name = "default"
                    nodeCount = _params.nodes.count
                    vmSize = _params.nodes.instanceType
                    vnetSubnetIdSelector.matchLabels = {
                        "azure.platform.upbound.io/network-id" = _params.id
                        "azure.platform.upbound.io/subnet-service-type" = "general"
                    }
                }
                dnsPrefix = _params.id
                identity.type = "SystemAssigned"
                kubernetesVersion = _params.version
                location = _params.region
                oidcIssuerEnabled = True
                workloadIdentityEnabled = True
                resourceGroupNameSelector.matchLabels = {
                    "azure.platform.upbound.io/network-id" = _params.id
                }
            }
            writeConnectionSecretToRef = {
                name = "{}-akscluster".format(oxr.metadata.name)
            }
        }
    }
    kubernetesmv1alpha1.Object {
        metadata = _metadata("workloadIdentitySettings")
        spec = {
            managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "ConfigMap"
                    metadata = {
                        name = "{}-workloadidentity-settings".format(_params.id)
                        namespace = "default"
                    }
                    data = {
                        oidc_url = dxr?.status?.aks?.oidcUrl
                    }
                }
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = _params.id
            }
        }
    }
    helmmv1beta1.ProviderConfig {
        metadata = {
            **_metadata("providerConfigHelm")
            annotations: {
                "krm.kcl.dev/ready" = "True"
            }
            name = _params.id
        }
        spec = {
            credentials = {
                secretRef = {
                    key = "kubeconfig"
                    name = "{}-akscluster".format(oxr.metadata.name)
                    namespace = oxr.metadata.namespace
                }
                source = "Secret"
            }
        }
    }
    kubernetesmv1alpha1.ProviderConfig {
        metadata = {
            **_metadata("providerConfigKubernetes")
            annotations: {
                "krm.kcl.dev/ready" = "True"
            }
            name = _params.id
        }
        spec = {
            credentials = {
                secretRef = {
                    key = "kubeconfig"
                    name = "{}-akscluster".format(oxr.metadata.name)
                    namespace = oxr.metadata.namespace
                }
                source = "Secret"
            }
        }
    }
]

items = _items
