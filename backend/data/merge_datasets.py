import json
import urllib.parse
import os

list_txt_path = r"C:\Users\User\Downloads\list.txt"
factcheckinsights_json_path = r"C:\Users\User\Documents\Gemini3Pro\backend\data\factcheckinsights_data.json"
output_path = r"C:\Users\User\Documents\Gemini3Pro\backend\data\verified_domains.json"

def normalize_domain(url_or_domain: str) -> str:
    """Strips scheme, www., and paths from a URL or domain string."""
    if not url_or_domain:
        return ""
    
    # URL Decode first
    url_or_domain = urllib.parse.unquote(url_or_domain)
    url_or_domain = url_or_domain.strip().lower()
    
    # Handle pure domains (e.g. bbc.com)
    if not url_or_domain.startswith("http://") and not url_or_domain.startswith("https://"):
        url_or_domain = "http://" + url_or_domain
        
    try:
        parsed = urllib.parse.urlparse(url_or_domain)
        domain = parsed.netloc
        if domain.startswith("www."):
            domain = domain[4:]
        return domain
    except Exception:
        return ""

verified_domains = set()

# 1. Parse list.txt (IFCN List)
print("Parsing list.txt...")
if os.path.exists(list_txt_path):
    with open(list_txt_path, 'r', encoding='utf-8') as f:
        for line in f:
            domain = normalize_domain(line.strip())
            if domain:
                verified_domains.add(domain)

# 2. Parse FactCheckInsights JSON
print("Parsing FactCheckInsights JSON...")
if os.path.exists(factcheckinsights_json_path):
    with open(factcheckinsights_json_path, 'r', encoding='utf-8') as f:
        try:
            duke_data = json.load(f)
            claim_reviews = duke_data.get('claimReviews', []) if isinstance(duke_data, dict) else duke_data
            for item in claim_reviews:
                if isinstance(item, dict):
                    # Extract from author.url or url
                    author_url = item.get("author", {}).get("url")
                    if author_url:
                        domain = normalize_domain(author_url)
                        if domain:
                            verified_domains.add(domain)
                        
                    # Assuming 'url' might also be present at the top level of 'item' if it's not an author URL
                    review_url = item.get('url', '') 
                    domain2 = normalize_domain(review_url)
                    if domain2:
                        verified_domains.add(domain2)
        except Exception as e:
            print(f"Error parsing Duke JSON: {e}")

# 3. Save combined set
print(f"Total Unique Verified Domains: {len(verified_domains)}")
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(sorted(list(verified_domains)), f, indent=2)

print(f"Successfully saved to {output_path}")
