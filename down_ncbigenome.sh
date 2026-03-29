#!/bin/bash
# ==========================================
# Script corregido: down_ncbigenome.sh
# ==========================================

# Activar Conda correctamente dentro del script
source $(conda info --base)/etc/profile.d/conda.sh
conda activate quastplus

# Salir si hay error o variable no definida
set -e
set -u

# ==========================================
# Variables
# ==========================================
BUSCO_LINEAGE=$1
OUTPUT_DIR="AssemblyQC"
NUM_THREADS=${2:-4}  # Usa el segundo argumento o 4 por defecto
ASSEMBLIES=("GCA_011022315.1" "GCA_031590215.1" "GCA_050947715.1")

if [ -z "$BUSCO_LINEAGE" ]; then
    echo "Usage: $0 <BUSCO_lineage>"
    exit 1
fi

# ==========================================
# Loop through each assembly
# ==========================================
for ASSEMBLY_ID in "${ASSEMBLIES[@]}"; do
    echo "==========================================="
    echo "Processing assembly: $ASSEMBLY_ID"
    echo "==========================================="

    WORKDIR="$OUTPUT_DIR/$ASSEMBLY_ID"
    mkdir -p "$WORKDIR"

    # Medir tiempo de todos los pasos
    time (
        # 1. Descargar genoma usando ASSEMBLY_ID
        echo "Downloading genome $ASSEMBLY_ID ..."
        datasets download genome accession "$ASSEMBLY_ID" --include genome,seq-report
        unzip -o ncbi_dataset.zip -d ncbi_dataset

        # 2. Localizar archivo FASTA
        GENOME_FILE=$(find ncbi_dataset -name "*.fna" | head -n 1)
        if [ ! -f "$GENOME_FILE" ]; then
            echo "Error: genome file not found for $ASSEMBLY_ID!"
            continue
        fi
        echo "Genome file located: $GENOME_FILE"

        # 3. Ejecutar QUAST
        echo "Running QUAST ..."
        quast -o "$WORKDIR/$ASSEMBLY_ID.quast" "$GENOME_FILE"

        # 4. Ejecutar BUSCO
        echo "Running BUSCO ..."
        busco -i "$GENOME_FILE" \
              -o "$WORKDIR/$ASSEMBLY_ID.busco.$BUSCO_LINEAGE" \
              -l "$BUSCO_LINEAGE" \
              -m genome \
              -c $NUM_THREADS \
              -f

        # 5. Generar resumen
        SUMMARY_FILE="$WORKDIR/${ASSEMBLY_ID}_summary.txt"
        echo "Assembly: $ASSEMBLY_ID" > "$SUMMARY_FILE"
        echo "==============================" >> "$SUMMARY_FILE"

        echo "QUAST metrics:" >> "$SUMMARY_FILE"
        grep -E "Total length|GC (%)|N50|# contigs" "$WORKDIR/$ASSEMBLY_ID.quast/report.txt" >> "$SUMMARY_FILE"

        echo "BUSCO metrics:" >> "$SUMMARY_FILE"
        grep "C:" "$WORKDIR/$ASSEMBLY_ID.busco.$BUSCO_LINEAGE/short_summary*" >> "$SUMMARY_FILE"

        echo "Summary saved to $SUMMARY_FILE"
    )
done

echo "==========================================="
echo "All assemblies processed. Results are in $OUTPUT_DIR/"
echo "==========================================="
