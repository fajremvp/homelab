* **Cluster Kubernetes:** `[Cluster de VMs - Talos Linux]`
    * **Justificativa:** Uso do **Talos Linux**, um SO imutável e minimalista projetado exclusivamente para rodar Kubernetes. O Talos gerencia o ciclo de vida do cluster via API (não é necessário instalar K3s manualmente sobre um Debian, o próprio SO é o cluster).
    * **Topologia:** 3 VMs (1 Control Plane + 2 Workers) para simular um ambiente de alta disponibilidade real e aprender a arquitetura distribuída.
    * **ArgoCD:** `[Aplicação - K8s]` - Rodará *dentro* do cluster.
    * **Linkerd (Service Mesh):** `[Aplicação - K8s]` - Plano inicial para aprender conceitos de malha de serviço.
    * **Storage Persistente (CSI):** `[NFS via ZFS Host]`
        * **Justificativa (Eficiência):** Substituição do Rook/Ceph. Em arquitetura *single-node*, rodar Ceph (replicado) sobre ZFS (já espelhado) gera uma **"Write Amplification" brutal** (desgaste inútil de SSD) e consome RAM excessiva (~4GB+ só para existir).
        * **Proteção de Dados:** Configurar **ZFS Auto-Snapshot** (frequência diária, retenção de 7 dias) no dataset `rpool/data/k8s_storage` para permitir recuperação instantânea em caso de exclusão acidental de PVCs ou corrupção de banco de dados dentro do cluster.
 **Arquitetura:**
            - **No Host (Proxmox):** Um Dataset ZFS dedicado (ex: `rpool/data/k8s_storage`) compartilhado via servidor NFS (Kernel Server) restrito à VLAN 60.
            - **No Cluster (Talos):** Uso do **`nfs-subdir-external-provisioner`**.
        * **Funcionamento:** Quando um Pod solicita armazenamento (PVC), o provisionador cria automaticamente uma subpasta no dataset do Host.
        * **Vantagens:** Performance nativa do NVMe (sem overhead de replicação de software), economia drástica de RAM e backups simplificados (o Restic no Host faz backup direto da pasta, sem precisar de plugins complexos dentro do Kubernetes).

    * **Objetivo:** Aprender e treinar Kubernetes, GitOps e Service Mesh.
