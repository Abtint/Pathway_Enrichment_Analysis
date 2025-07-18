#!/usr/bin/env Rscript
# ------------------------------------------------------------
# Pathway Enrichment Analysis (GO + KEGG) – GENERAL TEMPLATE
# ------------------------------------------------------------
# • Accepts a table of DEGs with log2FC and regulation labels
# • Separates up- and down-regulated genes
# • Maps gene symbols → Entrez IDs via biomaRt
# • Runs GO (BP, CC, MF, ALL) and KEGG enrichment with clusterProfiler
# • Writes each result to an Excel workbook + individual sheets
# ------------------------------------------------------------

# ============================================================
# 1 · Settings you may want to change
# ============================================================
DEG_FILE        <- "shared_significant_DEGs.xlsx"   # must contain columns: symbol, Regulation
UP_TAG          <- "Upregulated in both"
DOWN_TAG        <- "Downregulated in both"
ORGANISM_DB     <- "hsapiens_gene_ensembl"          # Ensembl dataset name
ENTREZ_ORG      <- "hsa"                            # KEGG organism code
GO_ONTOLOGY     <- "ALL"                            # "BP", "CC", "MF", or "ALL"
PVALUE_CUTOFF   <- 0.05
OUT_EXCEL       <- "Pathway_Enrichment_Results.xlsx"
UNMAPPED_EXCEL  <- "Unmapped_Genes.xlsx"

# ============================================================
# 2 · Libraries
# ============================================================
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(clusterProfiler)
  library(enrichplot)
  library(writexl)
  library(biomaRt)
  library(org.Hs.eg.db)    # change if using a different species
})

# ============================================================
# 3 · Load DEG list and split
# ============================================================
deg_tbl <- read_excel(DEG_FILE)

up_genes   <- deg_tbl %>% filter(Regulation == UP_TAG)   %>% pull(symbol)
down_genes <- deg_tbl %>% filter(Regulation == DOWN_TAG) %>% pull(symbol)

# ============================================================
# 4 · Map gene symbols → Entrez IDs
# ============================================================
mart <- useMart("ensembl", dataset = ORGANISM_DB)

map_ids <- function(gene_vec) {
  mapping <- getBM(
    attributes = c("hgnc_symbol", "entrezgene_id"),
    filters    = "hgnc_symbol",
    values     = gene_vec,
    mart       = mart
  )
  list(
    entrez = na.omit(mapping$entrezgene_id),
    unmapped = setdiff(gene_vec, mapping$hgnc_symbol)
  )
}

up_map   <- map_ids(up_genes)
down_map <- map_ids(down_genes)

write_xlsx(
  list(
    Unmapped_Up   = data.frame(symbol = up_map$unmapped),
    Unmapped_Down = data.frame(symbol = down_map$unmapped)
  ),
  UNMAPPED_EXCEL
)

# ============================================================
# 5 · Enrichment analyses
# ============================================================
go_up <- enrichGO(
  gene          = up_map$entrez,
  OrgDb         = org.Hs.eg.db,
  ont           = GO_ONTOLOGY,
  pAdjustMethod = "fdr",
  pvalueCutoff  = PVALUE_CUTOFF,
  readable      = TRUE
)

go_down <- enrichGO(
  gene          = down_map$entrez,
  OrgDb         = org.Hs.eg.db,
  ont           = GO_ONTOLOGY,
  pAdjustMethod = "fdr",
  pvalueCutoff  = PVALUE_CUTOFF,
  readable      = TRUE
)

kegg_up <- enrichKEGG(
  gene          = up_map$entrez,
  organism      = ENTREZ_ORG,
  pAdjustMethod = "fdr",
  pvalueCutoff  = PVALUE_CUTOFF
)

kegg_down <- enrichKEGG(
  gene          = down_map$entrez,
  organism      = ENTREZ_ORG,
  pAdjustMethod = "fdr",
  pvalueCutoff  = PVALUE_CUTOFF
)

# ============================================================
# 6 · Save results
# ============================================================
write_xlsx(
  list(
    GO_Upregulated        = as.data.frame(go_up),
    GO_Downregulated      = as.data.frame(go_down),
    KEGG_Upregulated      = as.data.frame(kegg_up),
    KEGG_Downregulated    = as.data.frame(kegg_down)
  ),
  OUT_EXCEL
)

# ============================================================
# 7 · Optional quick plots (top 15 terms)
# ============================================================
pdf("GO_Barplot_Upregulated.pdf", width = 6, height = 5)
barplot(go_up, showCategory = 15, title = "Top GO (Upregulated)")
dev.off()

pdf("KEGG_Barplot_Upregulated.pdf", width = 6, height = 5)
barplot(kegg_up, showCategory = 15, title = "Top KEGG (Upregulated)")
dev.off()

# ============================================================
# 8 · Console report
# ============================================================
cat("=== Pathway enrichment completed ===\n")
cat("  Up genes mapped   :", length(up_map$entrez), "\n")
cat("  Down genes mapped :", length(down_map$entrez), "\n")
cat("  Results written to:", OUT_EXCEL, "\n")
cat("  Unmapped genes    :", UNMAPPED_EXCEL, "\n")
