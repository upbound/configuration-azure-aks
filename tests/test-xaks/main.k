
import models.io.crossplane.helm.v1beta1 as helmv1beta1
import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.upbound.azure.containerservice.v1beta2 as containerservicev1beta2
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as upazurev1alpha1


_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-happy-path"
        spec= {
            assertResources: [
                upazurev1alpha1.XAKS{
                    metadata = {
                        name = "configuration-azure-aks"
                    }
                    spec = {
                        parameters = {
                            id = "configuration-azure-aks"
                            nodes = {
                                count = 1
                                instanceType = "Standard_B2s"
                            }
                            region = "westus"
                            version = "1.31"
                        }
                        writeConnectionSecretToRef = {
                            name = "configuration-azure-aks-kubeconfig"
                            namespace = "upbound-system"
                        }
                    }
                }
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
                                kind = "XAKS"
                                name = "configuration-azure-aks"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        forProvider = {
                            defaultNodePool = {
                                name = "default"
                                nodeCount = 1
                                vmSize = "Standard_B2s"
                                vnetSubnetIdSelector = {
                                    matchLabels = {
                                        "azure.platform.upbound.io/network-id" = "configuration-azure-aks"
                                    }
                                }
                            }
                            dnsPrefix = "configuration-azure-aks"
                            identity = {
                                $type = "SystemAssigned"
                            }
                            kubernetesVersion = "1.31"
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
                            name: "Undefined-akscluster"
                            namespace = "upbound-system"
                        }
                    }
                }

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
                                kind = "XAKS"
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
                                namespace = "upbound-system"
                            }
                            source = "Secret"
                        }
                    }
                }
                kubernetesv1alpha1.ProviderConfig{
                    metadata = {
                        annotations = {
                            "crossplane.io/composition-resource-name" = "providerConfigKubernetes"
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
                                kind = "XAKS"
                                name = "configuration-azure-aks"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        credentials = {
                            secretRef = {
                                key = "kubeconfig"
                                namespace = "upbound-system"
                                name = "Undefined-akscluster"
                            }
                            source = "Secret"
                        }
                    }
                }
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
                                kind = "XAKS"
                                name = "configuration-azure-aks"
                                uid = ""
                            }
                        ]
                    }
                    spec = {
                        deletionPolicy = "Orphan"
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
                            name = "configuration-azure-aks"
                        }
                    }
                }

            ]
            compositionPath: "apis/xaks/composition.yaml"
            xrPath: "examples/xaks/xaks.yaml"
            xrdPath: "apis/xaks/definition.yaml"
            timeoutSeconds: 60
            validate: False
        }
    }
]
items= _items
