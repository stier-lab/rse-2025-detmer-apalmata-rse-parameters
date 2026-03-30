#!/usr/bin/env python3
"""
Expanded PubMed search for A. palmata demographic synthesis.
Runs 6 additional queries beyond the original base query,
deduplicates PMIDs, and fetches metadata for all new records.
"""

import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import csv
import time
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# NCBI E-utilities endpoints
ESEARCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
EFETCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

# Rate limit: 0.5s between calls
SLEEP_SEC = 0.5


def esearch(query, retmax=5000):
    """Run an ESearch query and return (count, list_of_pmids)."""
    params = urllib.parse.urlencode({
        "db": "pubmed",
        "term": query,
        "retmax": retmax,
        "retmode": "xml",
        "usehistory": "n"
    })
    url = f"{ESEARCH_URL}?{params}"
    print(f"  ESearch: {url[:120]}...")

    req = urllib.request.Request(url)
    req.add_header("User-Agent", "CoralDemographySynthesis/1.0 (adrianstier@ucsb.edu)")

    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()

    root = ET.fromstring(data)
    count_el = root.find("Count")
    count = int(count_el.text) if count_el is not None else 0

    pmids = []
    id_list = root.find("IdList")
    if id_list is not None:
        for id_el in id_list.findall("Id"):
            pmids.append(id_el.text.strip())

    return count, pmids


def efetch_details(pmids, batch_size=100):
    """Fetch title, authors, year, journal for a list of PMIDs.
    Returns list of dicts with keys: pmid, first_author, year, title, journal, doi
    """
    results = []

    for i in range(0, len(pmids), batch_size):
        batch = pmids[i:i+batch_size]
        params = urllib.parse.urlencode({
            "db": "pubmed",
            "id": ",".join(batch),
            "retmode": "xml",
            "rettype": "abstract"
        })
        url = f"{EFETCH_URL}?{params}"
        print(f"  EFetch batch {i//batch_size + 1} ({len(batch)} PMIDs)...")

        req = urllib.request.Request(url)
        req.add_header("User-Agent", "CoralDemographySynthesis/1.0 (adrianstier@ucsb.edu)")

        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()

        root = ET.fromstring(data)

        for article in root.findall(".//PubmedArticle"):
            record = parse_article(article)
            if record:
                results.append(record)

        time.sleep(SLEEP_SEC)

    return results


def parse_article(article):
    """Parse a PubmedArticle XML element into a dict."""
    record = {
        "pmid": "",
        "first_author": "",
        "year": "",
        "title": "",
        "journal": "",
        "doi": ""
    }

    # PMID
    pmid_el = article.find(".//PMID")
    if pmid_el is not None:
        record["pmid"] = pmid_el.text.strip()

    # Title
    title_el = article.find(".//ArticleTitle")
    if title_el is not None:
        # Collect all text including within sub-elements (e.g., <i>)
        record["title"] = "".join(title_el.itertext()).strip()

    # Journal
    journal_el = article.find(".//Journal/Title")
    if journal_el is not None:
        record["journal"] = journal_el.text.strip() if journal_el.text else ""

    # Year — try multiple locations
    year = ""
    # ArticleDate
    for date_el in article.findall(".//ArticleDate"):
        y = date_el.find("Year")
        if y is not None:
            year = y.text.strip()
            break
    # PubDate
    if not year:
        pubdate = article.find(".//Journal/JournalIssue/PubDate")
        if pubdate is not None:
            y = pubdate.find("Year")
            if y is not None:
                year = y.text.strip()
            else:
                medline = pubdate.find("MedlineDate")
                if medline is not None and medline.text:
                    year = medline.text.strip()[:4]
    record["year"] = year

    # First author
    authors = article.findall(".//AuthorList/Author")
    if authors:
        last = authors[0].find("LastName")
        if last is not None and last.text:
            record["first_author"] = last.text.strip()
        else:
            collective = authors[0].find("CollectiveName")
            if collective is not None and collective.text:
                record["first_author"] = collective.text.strip()

    # DOI
    for eid in article.findall(".//ELocationID"):
        if eid.get("EIdType") == "doi":
            record["doi"] = eid.text.strip() if eid.text else ""
            break
    if not record["doi"]:
        for aid in article.findall(".//ArticleIdList/ArticleId"):
            if aid.get("IdType") == "doi":
                record["doi"] = aid.text.strip() if aid.text else ""
                break

    return record


def main():
    print("=" * 70)
    print("EXPANDED PUBMED SEARCH FOR A. PALMATA DEMOGRAPHIC SYNTHESIS")
    print("=" * 70)

    # Load original 124 PMIDs
    original_file = os.path.join(BASE_DIR, "pubmed_all_pmids.txt")
    original_pmids = set()
    with open(original_file, "r") as f:
        for line in f:
            pmid = line.strip()
            if pmid:
                original_pmids.add(pmid)
    print(f"\nLoaded {len(original_pmids)} original PMIDs from base query.")

    # Define expanded queries
    queries = {
        "Q0_base": '("Acropora palmata"[Title/Abstract] OR "elkhorn coral"[Title/Abstract])',
        "Q1_genus_caribbean": '("Acropora"[Title/Abstract] AND "Caribbean"[Title/Abstract])',
        "Q2_abbreviated": '("A. palmata"[Title/Abstract])',
        "Q3_mesh_anthozoa": '("Acropora palmata"[MeSH] OR ("Anthozoa"[MeSH] AND ("survival"[Title/Abstract] OR "mortality"[Title/Abstract]) AND "Caribbean"[Title/Abstract]))',
        "Q4_esa_threatened": '(("threatened coral"[Title/Abstract] OR "endangered coral"[Title/Abstract] OR "ESA coral"[Title/Abstract]) AND "Caribbean"[Title/Abstract])',
        "Q5_restoration": '("coral restoration"[Title/Abstract] AND "Caribbean"[Title/Abstract] AND ("survival"[Title/Abstract] OR "growth"[Title/Abstract]))',
        "Q6_spanish": '("cuerno de alce"[Title/Abstract] OR "coral cuerno"[Title/Abstract])',
    }

    # Run each query
    all_pmids = set(original_pmids)  # Start with originals
    query_results = {}

    for qname, query in queries.items():
        print(f"\n--- {qname} ---")
        print(f"  Query: {query}")
        time.sleep(SLEEP_SEC)

        try:
            count, pmids = esearch(query)
            query_results[qname] = {
                "query": query,
                "count": count,
                "pmids": set(pmids),
                "new_pmids": set(pmids) - original_pmids
            }
            all_pmids.update(pmids)
            print(f"  Hits: {count} | Retrieved: {len(pmids)} | New (not in original 124): {len(query_results[qname]['new_pmids'])}")
        except Exception as e:
            print(f"  ERROR: {e}")
            query_results[qname] = {
                "query": query,
                "count": 0,
                "pmids": set(),
                "new_pmids": set()
            }

    # Summary
    new_pmids = all_pmids - original_pmids
    print(f"\n{'=' * 70}")
    print("SUMMARY")
    print(f"{'=' * 70}")
    print(f"Original base query PMIDs:    {len(original_pmids)}")
    print(f"Total unique PMIDs (all queries): {len(all_pmids)}")
    print(f"NEW PMIDs (not in original):      {len(new_pmids)}")
    print()

    # Per-query breakdown
    print(f"{'Query':<25} {'Hits':>6} {'Retrieved':>10} {'New':>6}")
    print("-" * 55)
    for qname, res in query_results.items():
        print(f"{qname:<25} {res['count']:>6} {len(res['pmids']):>10} {len(res['new_pmids']):>6}")

    # Fetch metadata for new PMIDs
    if new_pmids:
        print(f"\nFetching metadata for {len(new_pmids)} new PMIDs...")
        new_pmid_list = sorted(new_pmids)
        details = efetch_details(new_pmid_list)
        print(f"  Retrieved metadata for {len(details)} records.")

        # Also track which queries each new PMID came from
        pmid_sources = {}
        for qname, res in query_results.items():
            for pmid in res["new_pmids"]:
                if pmid not in pmid_sources:
                    pmid_sources[pmid] = []
                pmid_sources[pmid].append(qname)

        # Write CSV with new PMIDs
        csv_path = os.path.join(BASE_DIR, "pubmed_expanded_queries.csv")
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["pmid", "first_author", "year", "title", "journal", "doi", "source_queries"])

            # Sort by year descending, then PMID descending
            details_sorted = sorted(details, key=lambda x: (x.get("year", "0000"), x.get("pmid", "0")), reverse=True)

            for rec in details_sorted:
                sources = "; ".join(pmid_sources.get(rec["pmid"], ["unknown"]))
                writer.writerow([
                    rec["pmid"],
                    rec["first_author"],
                    rec["year"],
                    rec["title"],
                    rec["journal"],
                    rec["doi"],
                    sources
                ])
        print(f"  Saved: {csv_path}")
    else:
        print("\nNo new PMIDs found beyond the original set.")
        csv_path = os.path.join(BASE_DIR, "pubmed_expanded_queries.csv")
        with open(csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["pmid", "first_author", "year", "title", "journal", "doi", "source_queries"])
        print(f"  Saved empty CSV: {csv_path}")

    # Write all PMIDs (union) to text file
    all_pmids_path = os.path.join(BASE_DIR, "pubmed_all_expanded.txt")
    with open(all_pmids_path, "w") as f:
        for pmid in sorted(all_pmids, key=lambda x: int(x) if x.isdigit() else 0, reverse=True):
            f.write(f"{pmid}\n")
    print(f"  Saved: {all_pmids_path} ({len(all_pmids)} total PMIDs)")

    # Write query log
    log_path = os.path.join(BASE_DIR, "pubmed_expanded_query_log.txt")
    with open(log_path, "w") as f:
        f.write("EXPANDED PUBMED SEARCH LOG\n")
        f.write(f"Date: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Original PMIDs: {len(original_pmids)}\n")
        f.write(f"Total unique PMIDs: {len(all_pmids)}\n")
        f.write(f"New PMIDs: {len(new_pmids)}\n\n")
        for qname, res in query_results.items():
            f.write(f"{qname}:\n")
            f.write(f"  Query: {res['query']}\n")
            f.write(f"  Hits: {res['count']}\n")
            f.write(f"  Retrieved: {len(res['pmids'])}\n")
            f.write(f"  New: {len(res['new_pmids'])}\n\n")
    print(f"  Saved: {log_path}")

    print(f"\nDone.")


if __name__ == "__main__":
    main()
