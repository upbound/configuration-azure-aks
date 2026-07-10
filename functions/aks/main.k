import models.io.upbound.azurem.containerservice.v1beta1 as azureContainerServicev1beta1
import models.io.upbound.platform.azure.v1alpha1.aks
import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesmv1alpha1
import models.io.crossplane.helmm.v1beta1 as helmmv1beta1

schema DefaultSpec:
    managementPolicies: [str]
    providerConfigRef: {str:str}
    forProvider: {str:str}

# Strip spec.crossplane before typed construction: under up v0.50.0 the observed
# composite carries spec.crossplane.resourceRefs as untyped dicts, which fails the
# typed AKS schema's resourceRefs validation. This composition never reads
# spec.crossplane, so dropping it is safe and keeps output byte-identical.
_oxrRaw = option("params").oxr
oxr = aks.AKS {**{k = v for k, v in _oxrRaw if k != "spec"}, **{"spec" = {k = v for k, v in (_oxrRaw?.spec or {}) if k != "crossplane"}}}
dxr = option("params").dxr
ocds = option("params").ocds

_metadata = lambda name: str -> any {
    {
        annotations = {"krm.kcl.dev/composition-resource-name" = name}
    }
}

_defaultSpec = DefaultSpec {
    managementPolicies = oxr.spec.parameters.managementPolicies or ["*"]
    providerConfigRef = {
        kind = "ProviderConfig"
        name = oxr.spec.parameters.providerConfigName or "default"
    }
    forProvider = {}
}

_items = [
    aks.AKS {
        **dxr
        spec.parameters = {
            id = oxr.spec.parameters.id
            nodes = oxr.spec.parameters.nodes
            region = oxr.spec.parameters.region
        }
        status = {
            aks = {
                oidcUrl = ocds?.kubernetesCluster?.Resource?.status?.atProvider?.oidcIssuerUrl
                clusterName = ocds?.kubernetesCluster?.Resource?.metadata?.name
                nodes = {
                    vmSize = ocds?.kubernetesCluster?.Resource?.status?.atProvider?.defaultNodePool?.vmSize
                }
            }
        }
    }
    azureContainerServicev1beta1.KubernetesCluster {
        metadata = {
            **_metadata("kubernetesCluster")
            name = "{}-aks".format(oxr.spec.parameters.id)
        }
        spec = {
            **_defaultSpec
            forProvider = {
                defaultNodePool = {
                    name = "default"
                    nodeCount = oxr.spec.parameters.nodes.count
                    vmSize = oxr.spec.parameters.nodes.instanceType
                    if oxr.spec.parameters.nodes?.availabilityZones:
                        zones = oxr.spec.parameters.nodes.availabilityZones
                    vnetSubnetIdSelector.matchLabels = {
                        "azure.platform.upbound.io/network-id" = oxr.spec.parameters.id
                        "azure.platform.upbound.io/subnet-service-type" = "general"
                    }
                }
                dnsPrefix = oxr.spec.parameters.id
                identity.type = "SystemAssigned"
                kubernetesVersion = oxr.spec.parameters.version
                location = oxr.spec.parameters.region
                oidcIssuerEnabled = True
                workloadIdentityEnabled = True
                resourceGroupNameSelector.matchLabels = {
                    "azure.platform.upbound.io/network-id" = oxr.spec.parameters.id
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
                        name = "{}-workloadidentity-settings".format(oxr.spec.parameters.id)
                        namespace = "default"
                    }
                    data = {
                        oidc_url = dxr?.status?.aks?.oidcUrl
                    }
                }
            }
            providerConfigRef = {
                kind = "ProviderConfig"
                name = oxr.spec.parameters.id
            }
        }
    }
    helmmv1beta1.ProviderConfig {
        metadata = {
            **_metadata("providerConfigHelm")
            annotations: {
                "krm.kcl.dev/ready" = "True"
            }
            name = oxr.spec.parameters.id
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
            name = oxr.spec.parameters.id
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
