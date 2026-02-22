import json
import httpx
import time

URL = "http://localhost:8080/analyze"

tests = [
    {
        "name": "Test 1 -> TRUE",
        "claim": "Water boils at 100 degrees Celsius at sea level.",
        "expected": "TRUE"
    },
    {
        "name": "Test 2 -> MOSTLY_TRUE",
        "claim": "The speed of light is exactly 300,000 kilometers per second.",
        "expected": "MOSTLY_TRUE"
    },
    {
        "name": "Test 3 -> MIXTURE",
        "claim": "George Washington was the first President of the United States and he lived in the White House.",
        "expected": "MIXTURE"
    },
    {
        "name": "Test 4 -> MISLEADING",
        "claim": "Eating carrots significantly improves your vision and gives you the ability to see in the dark.",
        "expected": "MISLEADING"
    },
    {
        "name": "Test 5 -> MOSTLY_FALSE",
        "claim": "Humans only use 10% of their brains.",
        "expected": "MOSTLY_FALSE"
    },
    {
        "name": "Test 6 -> FALSE",
        "claim": "The Earth is a flat disk surrounded by an ice wall.",
        "expected": "FALSE"
    },
    {
        "name": "Test 7 -> UNVERIFIABLE",
        "claim": "There is a microscopic porcelain teapot orbiting the Sun somewhere between Earth and Mars.",
        "expected": "UNVERIFIABLE"
    },
    {
        "name": "Test 8 -> NOT_A_CLAIM",
        "claim": "Vanilla ice cream is vastly superior to chocolate ice cream, and I think everyone should eat it.",
        "expected": "NOT_A_CLAIM"
    }
]

print("Starting 8-Tier Integration Test...\n" + "="*50)

for test in tests:
    print(f"\nRunning {test['name']}")
    print(f"Claim: '{test['claim']}'")
    
    payload = {
        "request_id": "test_" + str(int(time.time())),
        "text_claim": test["claim"],
        "settings": {
            "enable_grounding": True,
            "forensic_depth": "high"
        }
    }
    
    try:
        response = httpx.post(URL, data={"metadata": json.dumps(payload)}, timeout=45.0)
        if response.status_code == 200:
            data = response.json()
            actual_verdict = data.get('verdict', 'MISSING_VERDICT')
            print(f"EXPECTED: {test['expected']} | ACTUAL: {actual_verdict}")
            if actual_verdict != test['expected']:
                print(f"❌ MISMATCH! Expected {test['expected']}, got {actual_verdict}")
            else:
                print(f"✅ PASS")
                
            if actual_verdict in ["MIXTURE", "MISLEADING"]:
                print(f"\n--- Analysis Detail ---\n{data.get('analysis')}\n-----------------------")
        else:
            print(f"Error {response.status_code}: {response.text}")
    except Exception as e:
         print(f"Request failed: {e}")
    time.sleep(2) # Prevent rate limiting

print("\n" + "="*50 + "\nTest Suite Complete.")
