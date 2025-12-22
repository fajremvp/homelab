* **Bitcoin Core (Full Node) (Sem depender de intermediários e terceiros):** `[VM Dedicada]`
    * **Justificativa:** Alto uso de I/O de disco e rede constante. Uma VM dedicada impede que ele cause latência ou sature os recursos de outros serviços críticos.
    * **Armazenamento:** Montado no **SSD SATA Dedicado**. Isso protege o NVMe principal de desgaste e latência.