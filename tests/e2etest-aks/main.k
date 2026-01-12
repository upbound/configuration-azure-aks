import models.io.upbound.azurem.v1beta1 as azurev1beta1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1


_items = [
    metav1alpha1.E2ETest{
        metadata.name = "e2etest-xaks-azure"
        spec = {
            # Configure Crossplane for the test environment
            crossplane = {
                version = "2.0.2-up.5"
                autoUpgrade.channel = "None"
            }

            # Define the conditions that indicate successful resource creation
            defaultConditions = [
                "Ready"
            ]

            # Define the resource to be created
            manifests = [
                platformazurev1alpha1.AKS{
                    metadata = {
                        name = "configuration-azure-aks"
                        namespace = "default"
                    }
                    spec = {
                        parameters = {
                            id = "configuration-azure-aks"
                            region = "westus"
                            version = "1.34"
                            nodes = {
                                count = 1
                                instanceType = "Standard_B2s"
                            }
                        }
                    }
                }
                platformazurev1alpha1.Network{
                    metadata = {
                        name = "configuration-azure-aks"
                        namespace = "default"
                    }
                    spec = {
                        parameters = {
                            id = "configuration-azure-aks"
                            region = "westus"
                            addressRange = "10.1.0.0/16"
                            generalSubnetRange = "10.1.1.0/24"
                        }
                    }
                }
            ]

            # Define the provider configuration
            extraResources = [
                azurev1beta1.ProviderConfig{
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
                    spec = {
                        credentials = {
                            source = "Upbound"
                        }
                        clientID = "bcf40abd-283c-494b-b186-03d6c864be51"
                        tenantID = "b9925bc4-8383-4c37-b9d2-fa456d1bb1c7"
                        subscriptionID = "038f2b7c-3265-43b8-8624-c9ad5da610a8"
                    }
                }

            ]

            # Test cleanup settings
            skipDelete = False

            # Set a reasonable timeout for resources to be provisioned
            timeoutSeconds = 3600
        }
    }
]
items= _items
