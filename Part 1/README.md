# Kubernetes Network Automation Workshop Labs - Part 1

Welcome to the **Kubernetes Network Workshop** repository! This collection of labs is designed to provide hands-on experience with setting up and managing a Kubernetes cluster, exploring its core components, and using Kubernetes to manage applications. Each lab builds on the previous one to deepen your understanding of Kubernetes fundamentals.

## Lab Overview

1. **[ac2-kubenet-ws-part1-a.md](ac2-kubenet-ws-part1-a.md): Setting Up a Kubernetes Cluster with `Kind`**  
   This lab guides you through creating a local Kubernetes cluster using `Kind` (Kubernetes in Docker) and introduces you to `kubectl`, Kubernetes' command-line tool. Key objectives include:
   - Installing and configuring `Kind` and `kubectl`.
   - Exploring essential Kubernetes components like `kube-apiserver`, `etcd`, `kube-scheduler`, and others within the `kube-system` namespace.
   - Understanding the roles of these core components in managing and maintaining the cluster.

2. **[ac2-kubenet-ws-part1-b.md](ac2-kubenet-ws-part1-b.md): Basic Kubernetes Elements and `cert-manager`**  
   This lab introduces Kubernetes objects such as nodes, pods, deployments, and labels using the `cert-manager` app for practical learning. Main topics include:
   - Deploying `cert-manager` for managing TLS certificates.
   - Interacting with Kubernetes objects: viewing, filtering, and describing resources.
   - Working with labels to organize and manage resources effectively.

3. **Extended Lab (Optional)**: [ac2-kubnet-part1-extended-lab.md](ac2-kubnet-part1-extended-lab.md)  
   This document provides an extended practice suggestion for after the main labs. It introduces additional concepts in custom resource definitions (CRDs) and reconciliation through a custom Kubernetes controller. This lab is not part of the primary workshop but serves as additional material for further learning.

## Getting Started

Each lab provides step-by-step instructions, making it easy to follow along, even if you are new to Kubernetes. You can start with [ac2-kubenet-ws-part1-a.md](ac2-kubenet-ws-part1-a.md) and progress to the next labs.

For best results, we recommend running these labs in a GitHub Codespace or a local development environment with Kubernetes and Docker installed.

Happy learning, and enjoy exploring Kubernetes!

--- 
