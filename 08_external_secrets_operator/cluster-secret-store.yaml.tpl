apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: ${cluster_secret_store_name}
spec:
  provider:
    gcpsm:
      projectID: "${gcp_project_id}"
      auth:
        secretRef:
          secretAccessKeySecretRef:
            name: "${service_account_secret_name}"
            key: "credentials.json"
            namespace: "${namespace}"
