* **Bitcoin Core (Full Node) (Sem depender de intermediários e terceiros):** `[VM Dedicada]`
    * **Justificativa:** Alto uso de I/O de disco e rede constante. Uma VM dedicada impede que ele cause latência ou sature os recursos de outros serviços críticos.
    * **Armazenamento:** Montado no **SSD SATA Dedicado**. Isso protege o NVMe principal de desgaste e latência.
### Requisitos de Armazenamento Críticos
- **Capacidade:** Mínimo 2TB (Blockchain atual ~700GB + índices electrum + crescimento).
- **Tecnologia:** SSD SATA ou NVMe. **HDDs mecânicos são proibidos** para a pasta de dados principal devido à latência de seek.
- **Cache DRAM (Obrigatório):** O SSD **deve** possuir DRAM Cache dedicada.
    - *Motivo:* Durante o IBD (Initial Block Download), o node realiza milhões de pequenas escritas aleatórias (IOPS) para indexar as UTXOs. SSDs "DRAM-less" saturam o buffer SLC rapidamente, fazendo a velocidade de sincronização cair para níveis de KB/s, transformando um processo de 2 dias em 2 semanas.
    - *Hardware Selecionado:* Samsung 870 EVO (Substituindo especificação anterior de SSD DRAM-less).
