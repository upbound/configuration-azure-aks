import models.io.upbound.azurem.containerservice.v1beta1 as azureContainerServicev1beta1
import models.io.upbound.platform.azure.v1alpha1.aks
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.k8s.api.core.v1 as corev1
import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.helmm.v1beta1 as helmv1beta1
import base64

# schema definitions
schema ObservedComposedResources:
    dxr: aks.AKS
    kubernetesCluster: azureContainerServicev1beta1.KubernetesCluster
    workloadIdentitySettings: kubernetesv1alpha1.Object
    providerConfigHelm: helmv1beta1.ProviderConfig
    providerConfigKubernetes: kubernetesv1alpha1.ProviderConfig
    connectionSecret: corev1.Secret

schema DefaultSpec:
    managementPolicies: [str]
    providerConfigRef: {str:str}
    forProvider: {str:str}

# external parameter initialization
dxr = option("params").dxr
oxr = option("params").oxr
ocds = option("params").ocds
_ocds = option("params").ocds or {}
oxrParams = aks.AKS.spec.parameters {**oxr.spec.parameters}
oxrSpec = aks.AKS.spec {**oxr.spec}
oxrMeta = metav1.ObjectMeta {**oxr.metadata}
# unified metadata declaration
_metadata = lambda name: str -> any {
    {
        annotations = {"krm.kcl.dev/composition-resource-name" = name}
    }
}
# spec defaults
_defaultSpec = DefaultSpec {
    managementPolicies = ["*"]
    providerConfigRef = {
        kind = "ProviderConfig"
        name = oxrParams.providerConfigName or "default"
    }
    forProvider = {
        location = oxrParams.region
    }
}
# main composition
_composition = ObservedComposedResources {
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
    kubernetesCluster = azureContainerServicev1beta1.KubernetesCluster {
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
                        "azure.platform.upbound.io/subnet-service-type" = "general"
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
            }
        }
    }
    workloadIdentitySettings = kubernetesv1alpha1.Object {
        metadata = _metadata("workloadIdentitySettings")
        spec = {
            managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]
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
                kind = "ProviderConfig"
                name = oxrSpec.parameters.id
            }
        }
    }
    providerConfigHelm = helmv1beta1.ProviderConfig {
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
                    namespace = oxrMeta.namespace
                }
                source = "Secret"
            }
        }
    }
    providerConfigKubernetes = kubernetesv1alpha1.ProviderConfig {
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
                    namespace = oxrMeta.namespace
                }
                source = "Secret"
            }
        }
    }
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
                kubeconfig = _ocds.kubernetesCluster.ConnectionDetails?.kubeconfig or ""
            }
        else:
            data = {}
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
