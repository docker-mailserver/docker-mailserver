# Persistence

There are two storage APIs in Kubernetes that handle persistence abstraction:

- volume.alpha.kubernetes.io/storage-class
- volume.beta.kubernetes.io/storage-class

These APIs have different behaviours, across different cluster versions. The alpha API will be used if a storage class is not specified in the `storageClass` input, as it defers storage to to the cluster and the cluster will provision some based on its configured defaults. However, if the administrator needs to provision this storage (such as in the local development environment), they should set the `storageClass` attribute to match their configured storage, after which the beta API will be used.

An example PV might look something like the following:

```yaml
  ---
  apiVersion: "v1"
  kind: "PersistentVolume"
  metadata:
    name: "foo-mysql"
    annotations:
      volume.beta.kubernetes.io/storage-class: "foo-mysql"
  spec:
    capacity:
      storage: "10Gi"
    accessModes:
      - "ReadWriteOnce"
    persistentVolumeReclaimPolicy: "Retain"
    hostPath:
      path: /mnt/mysql
```

## Backup Strategies

### Google Cloud Persistent Disk

Kubernetes does not come with any facility to automatically snapshot data on a regular basis. However, with the [k8s-snapshots](https://github.com/miracle2k/k8s-snapshots) application we can mark a persistent volume as requiring backup via a Kubernetes annotation:

```yaml
  ---
  apiVersion: "v1"
  kind: "PersistentVolume"
  metadata:
    name: "foo-mysql"
    annotations:
      backup.kubernetes.io/deltas: 1h 2d 30d 180d # <-- The annotation
  # ...
```

For more information, see the [k8s-snapshots](https://github.com/miracle2k/k8s-snapshots) repository.

### Everything Else

This is not a solution that any repository maintainer has had to solve yet, so they are unaware of any solution to this.

## Custom VS Automatic persistence

Kubernetes automating the provisioning and mounting of storage is very handy when first deploying an application. However, it makes all further operations maintaining that application harder as if the application is ever torn down, it cannot be brought back up (easily) with that same persistent volume. Thus, it's a good idea when deploying an application that the developer:

1. Creates the storage class specifically for this application, or
2. Creates the PVC manually so it can be associated with a particular disk

### Existing PersistentVolumeClaims

1. Create the PersistentVolumeClaim
```bash
$ cat <<EOT | kubectl create -f -		
---		
apiVersion: v1		
kind: PersistentVolumeClaim		
metadata:		
  name: test		
spec:		
  accessModes:		
    - ReadWriteOnce		
  resources:		
    requests:		
      storage: 2Gi		
  selector:		
    matchLabels:		
      volume_name: test		
EOT		
```		

2. Create the directory, on a worker		

```bash		
# mkdir -m 1777 /NFS_MOUNT/test		
```		

3. Install the chart		

```bash		
$ helm install --name test --set persistence.existingClaim=test .		
```
