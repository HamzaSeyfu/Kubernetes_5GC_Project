# Kubernetes 5G Core Project

**Cloud-native 5G Core deployment and validation lab built around Kubernetes.**

This repository documents hands-on work around deploying, configuring, testing, and troubleshooting a containerized 5G Core environment.

## Project scope

The project focuses on the operational side of a 5G Core running on Kubernetes:

- deployment of 5G Core components;
- Kubernetes manifests and environment configuration;
- service connectivity and network troubleshooting;
- validation through end-to-end tests;
- automation scripts for repeatable setup and checks;
- analysis of infrastructure and application failures.

## Core technologies

- Kubernetes
- Linux
- 5G Core networking
- AMF / SMF / UPF concepts
- TCP/IP
- NAT / routing / CNI
- Bash scripting
- connectivity testing
- infrastructure troubleshooting

## Validation approach

The environment is tested progressively:

1. Verify Kubernetes resources and service readiness.
2. Check pod status, logs, images, and configuration.
3. Validate network reachability between components.
4. Exercise end-to-end connectivity.
5. Use ping / throughput testing where applicable.
6. Investigate failures across application, container, and network layers.

## Repository structure

- `5GC minimal/` — minimal 5G Core environment
- `manifests/` — Kubernetes manifests
- `scripts/` — automation and helper scripts
- `run-tests.sh` — test orchestration
- `Autre/` — additional supporting material

## Engineering focus

This project is less about a one-click demo and more about understanding how a distributed telecom workload behaves when deployed on a container orchestration platform.

Typical failure domains include:

- pod startup and readiness;
- container images and runtime issues;
- service discovery;
- DNS;
- routing and NAT;
- CNI behavior;
- UPF-related connectivity;
- timeout and dependency failures.

## What this project demonstrates

- Kubernetes deployment and troubleshooting
- Systems and network debugging
- Cloud-native telecom architecture
- Automation of repetitive validation tasks
- Reading logs and correlating failures across layers
- Building reproducible technical procedures

---

**Status:** technical lab / portfolio project based on practical 5G Core and Kubernetes experimentation.
