import httpx
import json
import sys

def test_analyze(query="Earth is flat."):
    url = "http://127.0.0.1:8080/analyze"
    payload = {
        "request_id": "test-query",
        "text_claim": query,
        "settings": {
            "enable_grounding": True,
            "forensic_depth": "high"
        }
    }
    
    # The endpoint expects 'metadata' as a Form field
    data = {"metadata": json.dumps(payload)}
    
    print(f"--- Sending Query: '{query}' ---")
    try:
        # Use a longer timeout for grounding queries
        response = httpx.post(url, data=data, timeout=120.0)
        
        if response.status_code == 200:
            res = response.json()
            print(f"VERDICT: {res.get('verdict')}")
            print(f"CONFIDENCE: {res.get('confidence_score')}")
            print(f"ANALYSIS: {res.get('analysis')}")
            
            metrics = res.get("reliability_metrics")
            if metrics:
                print("\n[RELIABILITY METRICS]")
                print(f"  Reliability Score: {metrics.get('reliability_score')}")
                print(f"  AI Confidence: {metrics.get('ai_confidence')}")
                print(f"  Base Grounding: {metrics.get('base_grounding')}")
                print(f"  Consistency Bonus: {metrics.get('consistency_bonus')}")
                print(f"  Multimodal Bonus: {metrics.get('multimodal_bonus')}")
                print(f"  Verdict Label: {metrics.get('verdict_label')}")
                print(f"  Explanation: {metrics.get('explanation')}")
                print("  Segments Audit:")
                for i, seg in enumerate(metrics.get("segments", [])):
                    print(f"    - Seg {i}: {seg.get('top_source_domain')} (Score: {seg.get('top_source_score')})")
            else:
                print("\n[WARNING] No reliability_metrics returned.")
                
        else:
            print(f"FAILED (HTTP {response.status_code}): {response.text}")
            
    except Exception as e:
        print(f"ERROR: {str(e)}")

if __name__ == "__main__":
    q = sys.argv[1] if len(sys.argv) > 1 else "Earth is flat."
    test_analyze(q)
