import json
import urllib.parse
import os

list_txt_path = r"C:\Users\User\Downloads\list.txt"
duke_json_path = r"C:\Users\User\Documents\Gemini3Pro\backend\data\duke_lab_data.json"
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

# 2. Parse Duke Reporters' Lab JSON
print("Parsing Duke Reporters' Lab JSON...")
if os.path.exists(duke_json_path):
    with open(duke_json_path, 'r', encoding='utf-8') as f:
        try:
            duke_data = json.load(f)
            claim_reviews = duke_data.get('claimReviews', [])
            for review in claim_reviews:
                # Extract from author.url or url
                author_url = review.get('author', {}).get('url', '')
                domain = normalize_domain(author_url)
                if domain:
                    verified_domains.add(domain)
                    
                review_url = review.get('url', '')
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
