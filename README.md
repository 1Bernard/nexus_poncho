# Nexus Poncho: The Distributed Financial Monolith

**Nexus Poncho** is a production-grade, distributed platform built for "Elite" financial operations. It leverages **Event Sourcing (CQRS/ES)**, **Distributed Elixir**, and a **3-Tier Secure Network Topology** to ensure immutable auditing and high-availability.

---

## 🏛️ Project Architecture

The platform is designed as a **Modular Distributed Monolith**. It consists of three primary layers:

- **Soul (`/nexus`)**: The core domain logic, event-sourced aggregates, and projections.
- **Web (`/nexus_web`)**: The Phoenix-based DMZ layer for public ingress.
- **Shared (`/nexus_shared`)**: Common schemas, UUID logic, and precision arithmetic (Decimal).

---

## 📖 The Nexus Codex

For a deep dive into the platform's "Elite" standards, networking, and domain-driven design, see the **[Nexus Codex Index](file:///Users/bernard/dev/nexus_poncho/.agent/nexus_codex/index.md)**.

### Key Modules:
- **[Architecture & Topology](file:///Users/bernard/dev/nexus_poncho/.agent/nexus_codex/01-architecture.md)**
- **[Distributed Networking (DMZ)](file:///Users/bernard/dev/nexus_poncho/.agent/nexus_codex/10-distributed-networking.md)**
- **[Distributed Genesis (Dockerfile & Node Naming)](file:///Users/bernard/dev/nexus_poncho/.agent/nexus_codex/11-distributed-genesis.md)**
- **[Dependency Roles & Mission](file:///Users/bernard/dev/nexus_poncho/.agent/nexus_codex/12-dependency-roles.md)**
- **[Audit & Soul Standards](file:///Users/bernard/dev/nexus_poncho/.agent/nexus_codex/03-soul-elite-standards.md)**

---

## 🚀 Getting Started

Ensure you have **Docker** and **Docker Compose** installed.

### 1. Boot the Cluster
```bash
docker compose up -d --build
```

### 2. Verify Node Discovery
```bash
docker exec nexus_poncho-web-1 iex --name tester@172.24.0.100 --cookie nexus --eval "IO.inspect(Node.list())"
```

---

> [!IMPORTANT]
> All code in this repository must follow the **Nexus BDD Standard** and maintain 100% architectural compliance before being considered production-ready.
