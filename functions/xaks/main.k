import models.io.upbound.azure.containerservice.v1beta2 as azureContainerServicev1beta2
import models.io.upbound.platform.azure.v1alpha1.xaks
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.helm.v1beta1 as helmv1beta1

# schema definitions
schema ObservedComposedResources:
    dxr: xaks.XAKS
    kubernetesCluster: azureContainerServicev1beta2.KubernetesCluster
    workloadIdentitySettings: kubernetesv1alpha1.Object
    providerConfigHelm: helmv1beta1.ProviderConfig
    providerConfigKubernetes: kubernetesv1alpha1.ProviderConfig

schema DefaultSpec:
    deletionPolicy: str
    providerConfigRef: {str:str}
    forProvider: {str:str}

schema CompositeConnectionDetails:
    apiVersion: str = "meta.krm.kcl.dev/v1alpha1"
    kind: str = "CompositeConnectionDetails"
    data: {str:str}

# external parameter initialization
dxr = option("params").dxr
oxr = option("params").oxr
ocds = option("params").ocds
oxrParams = xaks.XAKS.spec.parameters {**oxr.spec.parameters}
oxrSpec = xaks.XAKS.spec {**oxr.spec}
oxrMeta = metav1.ObjectMeta {**oxr.metadata}

# unified metadata declaration
_metadata = lambda name: str -> any {
    {
        annotations = {"krm.kcl.dev/composition-resource-name" = name}
    }
}
# spec defaults
_defaultSpec = DefaultSpec {
    deletionPolicy = oxrParams.deletionPolicy or "Delete"
    providerConfigRef = {
        name = oxrParams.providerConfigName or "default"
    }
    forProvider = {
        location = oxrParams.region
    }
}
# main composition
_composition = ObservedComposedResources {
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
    kubernetesCluster = azureContainerServicev1beta2.KubernetesCluster {
        metadata = {
            **_metadata("kubernetesCluster")
            name = "{}-aks".format(oxrParams.id)
        }
        spec = {
            **_defaultSpec
            forProvider = {
                defaultNodePool = {
                    name = "default"
                    nodeCount = oxrParams.nodes.count
                    vmSize = oxrParams.nodes.instanceType
                    vnetSubnetIdSelector.matchLabels = {
                        "azure.platform.upbound.io/network-id" = oxrParams.id
                    }
                }
                dnsPrefix = oxrParams.id
                identity.type = "SystemAssigned"
                kubernetesVersion = oxrParams.version
                location = oxrParams.region
                oidcIssuerEnabled = True
                workloadIdentityEnabled = True
                resourceGroupNameSelector.matchLabels = {
                    "azure.platform.upbound.io/network-id" = oxrParams.id
                }
            }
            writeConnectionSecretToRef = {
                name = "{}-akscluster".format(oxrMeta.uid)
                namespace = oxrSpec.writeConnectionSecretToRef.namespace
            }
        }
    }
    workloadIdentitySettings = kubernetesv1alpha1.Object {
        metadata = _metadata("workloadIdentitySettings")
        spec = {
            deletionPolicy = "Orphan"
            forProvider = {
                manifest = {
                    apiVersion = "v1"
                    kind = "ConfigMap"
                    metadata = {
                        name = "{}-workloadidentity-settings".format(oxrParams.id)
                        namespace = "default"
                    }
                    data = {
                        oidc_url = dxr.status.aks.oidcUrl
                    }
                }
            }
            providerConfigRef = {
                name = oxrSpec.parameters.id
            }
        }
    }
    providerConfigHelm = helmv1beta1.ProviderConfig{
        metadata: {
            **_metadata("providerConfigHelm")
            annotations: {
                "krm.kcl.dev/ready" = "True"
            }
            name = oxrSpec.parameters.id
        }
        spec = {
            credentials = {
                secretRef = {
                    key = "kubeconfig"
                    name = "{}-akscluster".format(oxrMeta.uid)
                    namespace = oxrSpec.writeConnectionSecretToRef.namespace
                }
                source = "Secret"
            }
        }
    }
    providerConfigKubernetes = kubernetesv1alpha1.ProviderConfig{
        metadata = {
            **_metadata("providerConfigKubernetes")
            annotations: {
                "krm.kcl.dev/ready" = "True"
            }
            name = oxrSpec.parameters.id
        }
        spec = {
            credentials = {
                secretRef = {
                    key = "kubeconfig"
                    name = "{}-akscluster".format(oxrMeta.uid)
                    namespace = oxrSpec.writeConnectionSecretToRef.namespace
                }
                source = "Secret"
            }
        }
    }
}
# special render function
# Idea is to support output in the form of a typed object instead
# of a list so we can make full typing assumptions, sum serves
# as a matter of flatten here, see:
# https://github.com/kcl-lang/kcl-lang.io/issues/310
_compileComposition = lambda byResourceType: ObservedComposedResources -> [any] {
    sum([[res for res in byResourceType[element]] if typeof(byResourceType[element]) == typeof([]) else [byResourceType[element]] for element in byResourceType], [])
}
# render output
items = _compileComposition(_composition)
