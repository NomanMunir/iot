# Inception of Things (IoT)

This repository contains the mandatory parts of the **Inception-of-Things** subject:

- **p1**: K3s + Vagrant (2 VMs: server + worker)
- **p2**: K3s + 3 simple apps + Ingress (1 VM)
- **p3**: K3d + Argo CD (GitOps)

## Prerequisites

- VirtualBox
- Vagrant

> The subject expects the project to be done inside a VM. In practice you can run Vagrant from Windows/macOS/Linux as long as VirtualBox + Vagrant work reliably.

## Repository layout

- `p1/`: 2-node K3s cluster (server + agent)
- `p2/`: single-node K3s cluster hosting 3 apps behind an Ingress
- `p3/`: k3d + Argo CD setup scripts + Argo application config

---

## Part 1 (p1) — 2 VMs, K3s server + agent

### What it does

- Creates two VMs:
	- `nmunirS` (server/controller) @ `192.168.56.110`
	- `nmunirSW` (worker/agent) @ `192.168.56.111`
- Installs K3s:
	- server mode on `nmunirS`
	- agent mode on `nmunirSW`
- Shares a generated join token via `/vagrant/node-token`.

### Run

From `p1/`:

```bash
vagrant up
vagrant ssh nmunirS
```

### Verify (inside `nmunirS`)

```bash
kubectl get nodes -o wide
```

Expected: 2 nodes, both eventually `Ready`.

---

## Part 2 (p2) — 1 VM, 3 apps, host-based routing

### Subject requirements implemented

- Single VM:
	- `nmunirS` @ `192.168.56.110`
- 3 web apps in K3s
- Routing by **Host header**:
	- `app1.com` → app1
	- `app2.com` → app2 (**3 replicas**)
	- anything else → app3 (default)

### Run

From `p2/`:

```bash
vagrant up
vagrant ssh nmunirS
```

### Verify (inside `nmunirS`)

```bash
kubectl get deploy,svc,ingress
kubectl get pods -o wide
```

Expected: `app2-deployment` shows 3 replicas.

### Test from your host machine

Use curl with an explicit Host header:

```bash
curl -H "Host: app1.com" http://192.168.56.110/
curl -H "Host: app2.com" http://192.168.56.110/
curl -H "Host: anything-else.com" http://192.168.56.110/
```

Expected responses:
- “Welcome to app1”
- “Welcome to app2”
- “Welcome to app3”

---

## Part 3 (p3) — K3d + Argo CD (GitOps)

### What it does

- Installs the required tooling (Docker, k3d, kubectl, etc.) using scripts in `p3/scripts/`
- Creates a k3d cluster
- Installs Argo CD into a dedicated namespace
- Creates a `dev` namespace and deploys an app via Argo CD

### Run

From `p3/`:

```bash
./scripts/setup.sh
```

### Notes

- Argo CD Application manifest: `p3/confs/application.yaml`
- GitOps repository content (the manifests Argo tracks): `p3/repo/app/`
- See `p3/repo/README.md` for the expected Git repository URL/path.

---

## Cleanup

```bash
# p1
cd p1 && vagrant destroy -f

# p2
cd ../p2 && vagrant destroy -f

# p3
cd ../p3 && ./scripts/cleanup.sh
```

---

## Defense checklist

- **P1**: show `kubectl get nodes` with server + worker.
- **P2**: demonstrate routing with Host header (`app1.com`, `app2.com`, default → app3) and show app2 has 3 replicas.
- **P3**: change the tracked manifests in the Git repo and show Argo CD syncing the updated version.
