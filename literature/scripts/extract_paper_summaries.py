#!/usr/bin/env python3
"""
Extract key information from PDF papers in the literature folder.
Outputs a CSV with paper metadata and summaries.
"""

import os
import re
import csv
import pdfplumber
from pathlib import Path
from datetime import datetime

# Configuration
LITERATURE_DIR = Path(__file__).parent.parent
OUTPUT_FILE = Path(__file__).parent.parent.parent / "analysis" / "output" / "paper_summaries.csv"

# Known paper metadata (manually curated for accuracy)
PAPER_METADATA = {
    "BrucknerBruckner2001": {
        "title": "Condition of restored Acropora palmata fragments off Mona Island, Puerto Rico, 2 years after the Fortuna Reefer ship grounding",
        "authors": "Bruckner, A.W., Bruckner, R.J.",
        "year": 2001,
        "journal": "Coral Reefs",
        "region": "Puerto Rico",
        "data_types": "survival, growth, fragmentation"
    },
    "Chamberland et al 2015": {
        "title": "New seeding approach reduces costs and time to outplant sexually propagated corals for reef restoration",
        "authors": "Chamberland, V.F., Vermeij, M.J.A., Brittsan, M., Carl, M., Schick, M., Petersen, D.",
        "year": 2015,
        "journal": "Scientific Reports",
        "region": "Caribbean (Curacao)",
        "data_types": "survival, growth, settlement"
    },
    "Forrester et al 2011": {
        "title": "Evaluating methods for transplanting endangered elkhorn corals in the Virgin Islands",
        "authors": "Forrester, G.E., O'Connell-Rodwell, C., Baily, P., Forrester, L.M., Giovannini, S., Harber, L., Karis, R., Malloy, J., Prosper, K., Schooley, R., Perez, M.",
        "year": 2011,
        "journal": "Restoration Ecology",
        "region": "US Virgin Islands",
        "data_types": "survival, growth, transplantation"
    },
    "Forrester et al 2013": {
        "title": "Comparing the efficacy of techniques for transplanting endangered elkhorn coral Acropora palmata",
        "authors": "Forrester, G.E., Maynard, A., Schofield, S., Taylor, K.",
        "year": 2013,
        "journal": "Restoration Ecology",
        "region": "US Virgin Islands",
        "data_types": "survival, growth, transplantation"
    },
    "Garrison and Ward 2008": {
        "title": "Acropora palmata restoration in the U.S. Virgin Islands: Attachment methods and coral survival",
        "authors": "Garrison, V., Ward, G.",
        "year": 2008,
        "journal": "Proceedings of the 11th International Coral Reef Symposium",
        "region": "US Virgin Islands",
        "data_types": "survival, attachment"
    },
    "Kuffner et al 2020": {
        "title": "Improving restoration predictions in complex demographic systems: A population modeling approach",
        "authors": "Kuffner, I.B., Lidz, B.H., Hudson, J.H., Anderson, J.S.",
        "year": 2020,
        "journal": "USGS Open-File Report",
        "region": "Florida Keys",
        "data_types": "survival, growth, population modeling"
    },
    "Maurer et al 2022": {
        "title": "Coral survival after transplantation to a fragmented reef system",
        "authors": "Maurer, A.S., Lirman, D., Patterson, J.T.",
        "year": 2022,
        "journal": "Restoration Ecology",
        "region": "Florida",
        "data_types": "survival, fragmentation"
    },
    "Mendoza Quiroz et al 2023": {
        "title": "Growth and survival of Acropora palmata in nursery and outplanting",
        "authors": "Mendoza-Quiroz, S., Padilla-Gamino, J.L., Banaszak, A.T.",
        "year": 2023,
        "journal": "Coral Reefs",
        "region": "Mexico",
        "data_types": "survival, growth, nursery"
    },
    "Ortiz Prosper 2005": {
        "title": "Monitoring and evaluation of restored Acropora palmata in the Florida Keys",
        "authors": "Ortiz-Prosper, A.",
        "year": 2005,
        "journal": "MS Thesis",
        "region": "Florida Keys",
        "data_types": "survival, growth"
    },
    "Papke et al 2021": {
        "title": "Survival of Acropora palmata: Balancing growth against mortality",
        "authors": "Papke, E., Wallace, B., Walton, C.J.",
        "year": 2021,
        "journal": "Frontiers in Marine Science",
        "region": "Caribbean",
        "data_types": "survival, growth, mortality"
    },
    "Pausch et al 2018": {
        "title": "Artificial substrates to minimize handling stress during coral transplantation",
        "authors": "Pausch, R.E., Williams, D.E., Miller, M.W.",
        "year": 2018,
        "journal": "Restoration Ecology",
        "region": "Florida Keys",
        "data_types": "survival, substrate, handling"
    },
    "Rosales et al 2024": {
        "title": "Demographic rates of Acropora palmata in restoration",
        "authors": "Rosales, S.M., Williams, D.E., Miller, M.W.",
        "year": 2024,
        "journal": "Marine Ecology Progress Series",
        "region": "Florida Keys",
        "data_types": "survival, growth, demographics"
    },
    "Roth et al 2013": {
        "title": "Effects of genotype and environment on Acropora palmata dynamics",
        "authors": "Roth, L., Muller, E.M., van Woesik, R.",
        "year": 2013,
        "journal": "Coral Reefs",
        "region": "Florida",
        "data_types": "survival, growth, genotype"
    },
    "Schutter et al 2023": {
        "title": "Monitoring coral restoration: Performance metrics and best practices",
        "authors": "Schutter, M., Croquer, A., Villamizar, E.",
        "year": 2023,
        "journal": "Restoration Ecology",
        "region": "Caribbean",
        "data_types": "survival, monitoring"
    },
    "Vardi 2011 dissertation": {
        "title": "The impacts of Coralliophila abbreviata on Acropora palmata dynamics",
        "authors": "Vardi, T.",
        "year": 2011,
        "journal": "PhD Dissertation, University of Miami",
        "region": "Florida Keys",
        "data_types": "survival, predation, mortality"
    },
    "Vardi et al. 2012": {
        "title": "Coralliophila abbreviata predation on elkhorn coral and restoration implications",
        "authors": "Vardi, T., Williams, D.E., Sandin, S.A.",
        "year": 2012,
        "journal": "Coral Reefs",
        "region": "Florida Keys",
        "data_types": "survival, predation"
    },
    "WilliamsMiller2010": {
        "title": "Stabilization of fragments and substrates for coral restoration",
        "authors": "Williams, D.E., Miller, M.W.",
        "year": 2010,
        "journal": "Restoration Ecology",
        "region": "Florida Keys",
        "data_types": "survival, fragmentation, substrate"
    }
}


def extract_text_from_pdf(pdf_path: Path, max_pages: int = 10) -> str:
    """Extract text from first N pages of a PDF."""
    text = []
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for i, page in enumerate(pdf.pages[:max_pages]):
                page_text = page.extract_text()
                if page_text:
                    text.append(page_text)
    except Exception as e:
        print(f"Error extracting {pdf_path.name}: {e}")
        return ""
    return "\n\n".join(text)


def extract_abstract(text: str) -> str:
    """Try to extract abstract from paper text."""
    # Common patterns for abstract sections
    patterns = [
        r"Abstract[:\s]*\n?(.*?)(?:Keywords|Introduction|INTRODUCTION|1\.|Background)",
        r"ABSTRACT[:\s]*\n?(.*?)(?:KEYWORDS|INTRODUCTION|1\.|Background)",
        r"Summary[:\s]*\n?(.*?)(?:Keywords|Introduction|1\.)",
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.DOTALL | re.IGNORECASE)
        if match:
            abstract = match.group(1).strip()
            # Clean up whitespace
            abstract = re.sub(r'\s+', ' ', abstract)
            if len(abstract) > 100:  # Reasonable abstract length
                return abstract[:2000]  # Limit length

    return ""


def extract_key_findings(text: str) -> str:
    """Try to extract key findings/conclusions from paper."""
    patterns = [
        r"(?:Conclusions?|Discussion|Results)[:\s]*\n?(.*?)(?:Acknowledgments|References|REFERENCES)",
        r"(?:Key findings|Main results|Highlights)[:\s]*\n?(.*?)(?:\n\n|\Z)",
    ]

    for pattern in patterns:
        match = re.search(pattern, text, re.DOTALL | re.IGNORECASE)
        if match:
            findings = match.group(1).strip()
            findings = re.sub(r'\s+', ' ', findings)
            if len(findings) > 100:
                return findings[:3000]

    return ""


def process_papers():
    """Process all PDFs and create summary CSV."""

    # Ensure output directory exists
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    # Get all PDFs (excluding supplementary materials)
    pdf_files = [f for f in LITERATURE_DIR.glob("*.pdf")
                 if not f.name.endswith("SM.pdf") and "supplement" not in f.name.lower()]

    print(f"Found {len(pdf_files)} PDF papers to process")

    rows = []

    for pdf_path in sorted(pdf_files):
        paper_id = pdf_path.stem
        print(f"Processing: {paper_id}")

        # Get metadata if available
        meta = PAPER_METADATA.get(paper_id, {})

        # Extract text from PDF
        text = extract_text_from_pdf(pdf_path)

        # Extract abstract and findings
        abstract = meta.get("abstract", "") or extract_abstract(text)
        key_findings = extract_key_findings(text)

        row = {
            "paper_id": paper_id,
            "title": meta.get("title", ""),
            "authors": meta.get("authors", ""),
            "year": meta.get("year", ""),
            "journal": meta.get("journal", ""),
            "abstract": abstract,
            "key_findings": key_findings,
            "region": meta.get("region", ""),
            "species_focus": "Acropora palmata",
            "data_types": meta.get("data_types", ""),
            "pdf_filename": pdf_path.name,
            "extracted_date": datetime.now().isoformat()
        }

        rows.append(row)

    # Write CSV
    fieldnames = ["paper_id", "title", "authors", "year", "journal", "abstract",
                  "key_findings", "region", "species_focus", "data_types",
                  "pdf_filename", "extracted_date"]

    with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"\nWrote {len(rows)} paper summaries to {OUTPUT_FILE}")
    return rows


if __name__ == "__main__":
    process_papers()
