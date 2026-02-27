import json
import httpx
import time

URL = "http://localhost:8080/analyze"

def test_tiered_evidence():
    print("Running Tiered Evidence Verification...")
    payload = {
        "request_id": "verify_tiered_" + str(int(time.time())),
        "text_claim": "The moon is made of cheese. Some say it is Gorgonzola.",
        "settings": {
            "enable_grounding": True,
            "forensic_depth": "high"
        }
    }
    
    try:
        response = httpx.post(URL, data={"metadata": json.dumps(payload)}, timeout=60.0)
        if response.status_code == 200:
            data = response.json()
            print("Response received successfully.")
            
            scanned = data.get('scanned_sources', [])
            citations = data.get('grounding_citations', [])
            
            print(f"Grounding Citations: {len(citations)}")
            print(f"Scanned Sources: {len(scanned)}")
            
            cited_urls = [normalize_url(c.get('url')) for c in citations if c.get('url')]
            
            pass_count = 0
            for s in scanned:
                norm_url = normalize_url(s.get('url'))
                actual_is_cited = s.get('is_cited')
                expected_is_cited = norm_url in cited_urls
                
                if actual_is_cited == expected_is_cited:
                    print(f"✅ Source '{s.get('title')[:30]}...' correctly flagged (is_cited={actual_is_cited})")
                    pass_count += 1
                else:
                    print(f"❌ Source '{s.get('title')[:30]}...' MISMATCH! Expected is_cited={expected_is_cited}, got {actual_is_cited}")

            if pass_count == len(scanned) and len(scanned) > 0:
                print("\nALL SCANNED SOURCES VERIFIED.")
            elif len(scanned) == 0:
                print("\nWARNING: No scanned sources found. (Might be a grounding failure)")
            else:
                print(f"\nVERIFICATION FAILED: {len(scanned) - pass_count} mismatches.")
        else:
            print(f"Error {response.status_code}: {response.text}")
    except Exception as e:
        print(f"Request failed: {e}")

import re
def normalize_url(url: str) -> str:
    if not url: return ""
    url = re.sub(r'^https?://', '', url.lower())
    url = re.sub(r'^www\.', '', url)
    return url.rstrip('/')

if __name__ == "__main__":
    test_tiered_evidence()
