
# Run on Kubernetes

NSD can be run on Kubernetes.

##

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nsd-dns-keys
  labels:
    app: nsd
data:
  Kdomain.tld.ksk.key: xxx
  Kdomain.tld.ksk.private: xxx
  Kdomain.tld.zsk.key: xxx
  Kdomain.tld.zsk.private: xxx
```


```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nsd
  labels:
    app: nsd
spec:
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  selector:
    matchLabels:
      app: nsd
  template:
    metadata:
      labels:
        app: nsd
    spec:
      containers:
      - name: nsd
        image: ghcr.io/the-kube-way/nsd:latest
        imagePullPolicy: Always
        resources:
          requests:
            cpu: 10m
            memory: 128M
          limits:
            cpu: 100m
            memory: 256M
        readinessProbe:
          tcpSocket:
            port: 53
          initialDelaySeconds: 5
          periodSeconds: 10
        ports:
        - containerPort: 53
        - containerPort: 53
          protocol: UDP
        volumeMounts:
        - name: config
          mountPath: /etc/nsd
        - name: zones
          mountPath: /zones
      initContainers:
      - name: init
        image: selfhostingtools/nsd:v1
        imagePullPolicy: Always
        args:
          - init.sh
        resources:
          requests:
            cpu: 10m
            memory: 128M
          limits:
            cpu: 100m
            memory: 256M
        volumeMounts:
        - name: zones-configmap
          mountPath: /zones_configmap
        - name: zones
          mountPath: /zones
        - name: dns-keys
          mountPath: /keys
      volumes:
      - name: config
        configMap:
          name: nsd-config
      - name: zones-configmap
        configMap:
          name: nsd-zones
      - name: zones
        emptyDir: {}
      - name: dns-keys
        secret:
          secretName: nsd-dns-keys
          defaultMode: 0400

---
apiVersion: v1
kind: Service
metadata:
  name: nsd
  labels:
    app: nsd
spec:
  ports:
  - port: 53
    name: dns
  - port: 53
    name: dns-udp
    protocol: UDP
  selector:
    app: nsd

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nsd-config
  labels:
    app: nsd
data:
  nsd.conf: |
    server:
      server-count: 1
      verbosity: 1
      zonesdir: "/zones"
      hide-version: yes
      statistics: 60

    zone:
      name: "domain.tld"
      zonefile: "domain.tld.signed"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nsd-zones
  labels:
    app: nsd
data:
  domain.tld: xxx
```


DNSSEC signatures expire after 28d. As this tool resigns dns zones at startup, the container should be restarted before then.
This cronjob restart the container on a weekly basis.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nsd-cron
  labels:
    app: nsd

---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nsd-rollout
  labels:
    app: nsd
rules:
- apiGroups:
  - apps
  resources:
  - deployments
  resourceNames:
  - nsd
  verbs:
  - get
  - patch

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: nsd
  labels:
    app: nsd
subjects:
- kind: ServiceAccount
  name: nsd-cron
roleRef:
  kind: Role
  name: nsd-rollout
  apiGroup: ""

---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: nsd-rollout
  labels:
    app: nsd
spec:
  schedule: "0 10 * * 6"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: nsd-cron
          containers:
          - name: rollout
            image: bitnami/kubectl:latest
            command:
            - sh
            - -c
            - kubectl rollout restart deployments nsd
          restartPolicy: OnFailure
```
