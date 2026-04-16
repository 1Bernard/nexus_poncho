# Nexus Poncho Operations Manual (Nexus Codex)

This manual documents the "Elite" operational standards for the Nexus Poncho distributed architecture. It serves as a guide for troubleshooting, health verification, and architectural consistency.

---

## 1. Architectural Patterns & Learnings

### Dynamic IP-Based Node Naming
In containerized environments (Docker), hostnames (e.g., `node1`) often fail Erlang's strict FQDN requirements for longnames (`--name`). Using shortnames (`--sname`) works but can conflict with DNS discovery.
- **Pattern**: Nodes are assigned their container's internal IP address at runtime.
- **Implementation**: `IP=$(hostname -i | cut -d' ' -f1) && iex --name nexus@$IP --cookie nexus -S mix`
- **Benefit**: `libcluster (DNSPoll)` resolves IPs from the service name (e.g., `web`) and perfectly matches the node name `nexus@IP`, ensuring seamless connectivity even if container IPs change.

### Layered Ingress Reachability
The system uses a 3-layer ingress stack for maximum resilience:
1. **Nginx** (Edge): External entry point (Port 80/443).
2. **HAProxy** (Load Balancer): Layer 4/7 balancing across Nodes (Port 4000).
3. **Bandit/Phoenix** (App Nodes): Distributed web servers (Port 4000 internal).

---

## 2. Diagnostic Battery

### Core Health Sweep
Run these commands to verify the baseline stability of the entire stack.

| Target | Command | Purpose |
| :--- | :--- | :--- |
| **All Services** | `docker compose ps` | Verify all containers are `Up` and `Healthy`. |
| **Edge Ingress** | `curl -I http://localhost:80/health` | Verify Nginx is routing to HAProxy. |
| **Load Balancer** | `curl -I http://localhost:4000/health` | Verify HAProxy is routing to Phoenix. |
| **Database** | `docker exec -it nexus_poncho-postgres-1 psql -U ledger -c "\dt"` | Verify EventStore tables are initialized. |
| **Mesh Density** | `docker compose logs web \| grep "connected to"` | Verify Elixir nodes have joined the cluster. |

### Advanced Troubleshooting

#### Internal Port Probing (If access fails)
If `curl` from the host fails, check if the service is listening *inside* the container:
```bash
docker exec nexus_poncho-web-1 netstat -ln | grep 4000
```
- **Expected Output**: `tcp 0 0 0.0.0.0:4000 0.0.0.0:* LISTEN`

#### Internal DNS Resolution
Verify that services can find each other within the `ledger_net` bridge:
```bash
docker exec nexus_poncho-nginx-1 getent hosts haproxy
docker exec nexus_poncho-haproxy-1 getent hosts web
```
- **Expected Output**: `172.23.0.x <service_name>`

#### HAProxy Health Status
Check the internal stats page to see which backends HAProxy considers "UP":
```bash
curl -s http://localhost:8404/stats | grep ",UP"
```

---

## 3. Operations Verification Guide

### Cluster Boot Sequence
1. **Network Layer**: `ledger_net` (Subnet 172.23.0.0/16).
2. **Persistence Layer**: `postgres` healthiest first (Wait for `Healthy`).
3. **Core Layer**: `node1`, `node2`, `web` bootstrap Elixir cluster (Wait for `libcluster` logs).
4. **Ingress Layer**: `haproxy` and `nginx` initialize backend health checks.

### Verification Matrix
| Component | Command | Success indicator |
| :--- | :--- | :--- |
| **Cluster** | `docker compose logs web` | `[info] [libcluster:nexus] connected to :"nexus@172.x.x.x"` |
| **Web App** | `curl -s http://localhost:80/` | Correct home page HTML returned. |
| **EventStore** | `docker compose logs node1` | `Subscription "Identity.UserProjector" attempting to connect` |
| **Observability**| `curl -s http://localhost:16686/` | Jaeger UI accessible. |

---

## 4. Known Issues & Maintenance

- **Orphaned Containers**: Reconfiguration often leaves legacy containers. Clean with:
  ```bash
  docker compose up -d --remove-orphans
  ```
- **OpenTelemetry Flushing**: Traces may take 5-10 seconds to appear in Jaeger due to the batch processor settings.
- **Node Collision**: If scaling manually, ensure each node name is unique (using the IP naming strategy avoids this).

---
*End of Codex*
