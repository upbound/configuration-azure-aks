import models.io.crossplane.helmm.v1beta1 as helmmv1beta1
import models.io.crossplane.kubernetesm.v1alpha1 as kubernetesmv1alpha1
import models.io.upbound.azurem.containerservice.v1beta1 as containerservicev1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as upazurev1alpha1

# Shared owner-reference uid for observed-resource fixtures: up v0.50.0 assigns
# the composite a deterministic uid, and owner refs must match it.
_ownerUid = "41fc1f8b-15d0-5034-be10-0ed93726503c"

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-happy-path"
        spec= {
            assertResources: [
                upazurev1alpha1.AKS{
                    metadata = {
                        name = "configuration-azure-aks"
                        namespace = "default"
                    }
                    spec = {
                        parameters = {
                            id = "configuration-azure-aks"
                            nodes = {
                                count = 1
                                instanceType = "Standard_B2s"
                            }
                            region = "westus"
                            version = "1.34"
                            managementPolicies = ["*"]
                        }
                    }
                }
                containerservicev1beta1.KubernetesCluster{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "kubernetesCluster"
                        }
                        labels = {
                            "crossplane.io/composite" = "configuration-azure-aks"
                        }
                        name = "configuration-azure-aks-aks"
                        namespace = "default"
                        ownerReferences = [
                            {
                                apiVersion = "azure.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "AKS"
                                name = "configuration-azure-aks"
                                uid = _ownerUid
                            }
                        ]
                    }
                    spec = {
                        managementPolicies = ["*"]
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "default"
                        }
                        forProvider = {
                            defaultNodePool = {
                                name = "default"
                                nodeCount = 1
                                vmSize = "Standard_B2s"
                                vnetSubnetIdSelector = {
                                    matchLabels = {
                                        "azure.platform.upbound.io/network-id" = "configuration-azure-aks"
                                        "azure.platform.upbound.io/subnet-service-type" = "general"
                                    }
                                }
                            }
                            dnsPrefix = "configuration-azure-aks"
                            identity = {
                                $type = "SystemAssigned"
                            }
                            kubernetesVersion = "1.34"
                            location = "westus"
                            oidcIssuerEnabled = True
                            resourceGroupNameSelector = {
                                matchLabels = {
                                    "azure.platform.upbound.io/network-id" = "configuration-azure-aks"
                                }
                            }
                            workloadIdentityEnabled = True
                        }
                        writeConnectionSecretToRef = {
                            name: "configuration-azure-aks-akscluster"
                        }
                    }
                }
                helmmv1beta1.ProviderConfig{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "providerConfigHelm"
                        }
                        labels = {
                            "crossplane.io/composite" = "configuration-azure-aks"
                        }
                        name = "configuration-azure-aks"
                        namespace = "default"
                        ownerReferences = [
                            {
                                apiVersion = "azure.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "AKS"
                                name = "configuration-azure-aks"
                                uid = _ownerUid
                            }
                        ]
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "kubeconfig"
                                name = "configuration-azure-aks-akscluster"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                    }
                }
                kubernetesmv1alpha1.ProviderConfig{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "providerConfigKubernetes"
                        }
                        labels = {
                            "crossplane.io/composite" = "configuration-azure-aks"
                        }
                        name = "configuration-azure-aks"
                        namespace = "default"
                        ownerReferences = [
                            {
                                apiVersion = "azure.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "AKS"
                                name = "configuration-azure-aks"
                                uid = _ownerUid
                            }
                        ]
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "kubeconfig"
                                name = "configuration-azure-aks-akscluster"
                                namespace = "default"
                            }
                            source = "Secret"
                        }
                    }
                }
                kubernetesmv1alpha1.Object{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "workloadIdentitySettings"
                        }
                        labels = {
                            "crossplane.io/composite" = "configuration-azure-aks"
                        }
                        name = "configuration-azure-aks-d7b3b1c32862"
                        namespace = "default"
                        ownerReferences = [
                            {
                                apiVersion = "azure.platform.upbound.io/v1alpha1"
                                blockOwnerDeletion = True
                                controller = True
                                kind = "AKS"
                                name = "configuration-azure-aks"
                                uid = _ownerUid
                            }
                        ]
                    }
                    spec = {
                        managementPolicies = ["Create", "Observe", "Update", "LateInitialize"]
                        forProvider = {
                            manifest = {
                                apiVersion = "v1"
                                kind = "ConfigMap"
                                metadata = {
                                    name = "configuration-azure-aks-workloadidentity-settings"
                                    namespace = "default"
                                }
                            }
                        }
                        providerConfigRef = {
                            kind = "ProviderConfig"
                            name = "configuration-azure-aks"
                        }
                    }
                }
            ]
            compositionPath: "apis/aks/composition.yaml"
            xrPath: "examples/aks/aks.yaml"
            xrdPath: "apis/aks/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
    metav1alpha1.CompositionTest{
        metadata.name: "test-status-propagation"
        spec = {
            observedResources: [
                containerservicev1beta1.KubernetesCluster{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "kubernetesCluster"
                        }
                        labels = {
                            "crossplane.io/composite" = "configuration-azure-aks"
                        }
                        name = "configuration-azure-aks-aks"
                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            defaultNodePool = {
                                name = "default"
                                nodeCount = 1
                                vmSize = "Standard_B2s"
                            }
                        }
                    }
                    status = {
                        atProvider = {
                            oidcIssuerUrl = "https://westus.oic.prod-aks.azure.com/example/"
                            defaultNodePool = {
                                vmSize = "Standard_B2s"
                            }
                        }
                    }
                }
            ]
            assertResources: [
                upazurev1alpha1.AKS{
                    metadata = {
                        name = "configuration-azure-aks"
                        namespace = "default"
                    }
                    spec = {
                        parameters = {
                            id = "configuration-azure-aks"
                            nodes = {
                                count = 1
                                instanceType = "Standard_B2s"
                            }
                            region = "westus"
                            version = "1.34"
                            managementPolicies = ["*"]
                        }
                    }
                    status = {
                        aks = {
                            clusterName = "configuration-azure-aks-aks"
                            oidcUrl = "https://westus.oic.prod-aks.azure.com/example/"
                            nodes = {
                                vmSize = "Standard_B2s"
                            }
                        }
                    }
                }
            ]
            compositionPath: "apis/aks/composition.yaml"
            xrPath: "examples/aks/aks.yaml"
            xrdPath: "apis/aks/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
    metav1alpha1.CompositionTest{
        metadata.name: "test-availability-zones"
        spec = {
            assertResources: [
                containerservicev1beta1.KubernetesCluster{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "kubernetesCluster"
                        }
                        labels = {
                            "crossplane.io/composite" = "configuration-azure-aks-zones"
                        }
                        name = "configuration-azure-aks-zones-aks"
                        namespace = "default"
                    }
                    spec = {
                        forProvider = {
                            defaultNodePool = {
                                name = "default"
                                nodeCount = 1
                                vmSize = "Standard_B2s"
                                zones = ["1", "2", "3"]
                            }
                        }
                    }
                }
            ]
            compositionPath: "apis/aks/composition.yaml"
            xrPath: "examples/aks/aks-zones.yaml"
            xrdPath: "apis/aks/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
