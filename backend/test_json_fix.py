import json
import re

def repair_and_parse_json(raw_text: str) -> dict:
    if not raw_text:
        raise ValueError("Empty response text")

    json_match = re.search(r'\{.*\}', raw_text, re.DOTALL)
    if not json_match:
        raise ValueError("No JSON object found in text")

    cleaned = json_match.group(0)

    # Attempt to fix trailing commas before closing braces/brackets
    cleaned = re.sub(r',\s*([\]}])', r'\1', cleaned)

    try:
        return json.loads(cleaned, strict=False)
    except json.JSONDecodeError:
        match = re.search(r'("analysis"\s*:\s*")(.*?)("\s*,\s*"multimodal_cross_check")', cleaned, re.DOTALL)
        if match:
            analysis_text = match.group(2)
            # Escape inner quotes
            escaped_text = analysis_text.replace('"', '\\"')
            # Reconstruct string
            cleaned = cleaned[:match.start(2)] + escaped_text + cleaned[match.end(2):]
            
        return json.loads(cleaned, strict=False)

with open('failed_json_dump.txt', 'r', encoding='utf-8') as f:
    dump_text = f.read()

try:
    data = repair_and_parse_json(dump_text)
    print("SUCCESS")
    print(data["analysis"])
except Exception as e:
    print(f"FAILED: {e}")
