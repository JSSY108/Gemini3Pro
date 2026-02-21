import re

def sanitize_grounding_text(text: str) -> str:
    """Strips JSON structural fragments from cited segments using aggressive multiline logic."""
    if not text:
        return ""
    
    # 1. Pre-strip code block artifacts
    text = text.replace("```json", "").replace("```", "").strip()
    
    # 2. Line-by-line cleanup for structural leakage
    lines = text.splitlines()
    cleaned_lines = []
    
    # Pattern for JSON keys: "verdict": or \"analysis\": or key_findings: [ 
    # Handles escaped quotes commonly found in leaked segments
    key_pattern = re.compile(r'^\s*(?:\\")?"?([\w_]+)(?:\\")?"?\s*:\s*', re.IGNORECASE)
    # Pattern for solo structural bits or boolean leaks
    structure_pattern = re.compile(r'^\s*[{}[\],"\\]+\s*$|^\s*(?:\\")?"?(?:true|false)(?:\\")?"?\s*,?\s*$', re.IGNORECASE)
    # Keys to skip entirely (structural/forensic metadata)
    metadata_keys = {"verdict", "confidence_score", "multimodal_cross_check", "type", "provided_url", "page_title"}

    for line in lines:
        s_line = line.strip()
        if not s_line:
            continue
            
        # If the line is a key pattern
        match = key_pattern.match(s_line)
        if match:
            key_name = match.group(1).lower()
            # If it's a metadata key, skip the entire line/value
            if key_name in metadata_keys:
                continue
                
            # If it's a content key (like "analysis"), try to take the value
            if ":" in s_line:
                value_part = s_line.split(":", 1)[1].strip().strip('",\\ ')
                if value_part and not structure_pattern.match(value_part):
                    # Value contains actual text, keep only the value!
                    cleaned_lines.append(value_part)
            continue
            
        # If it's just structural junk, skip it entirely
        if structure_pattern.match(s_line):
            continue
            
        # Otherwise, it's likely real content
        cleaned_lines.append(line)

    text = "\n".join(cleaned_lines).strip()
    
    # 3. Final cleanup of leading/trailing structural junk
    text = text.strip('"{},[] \n\r\t')
    # Remove trailing quotes and commas again after stripping
    text = re.sub(r'["\s,\]}\\]*$', '', text)
    
    return text.strip()

# TEST CASES from User Reports
test_cases = [
    {
        "name": "Mid-line Leakage (Key Findings)",
        "input": "\",\n\"multimodal_cross_check\": false,\n\"key_findings\": [\n\"The Great Wall of China is not visible from space with the naked eye",
        "expected": "The Great Wall of China is not visible from space with the naked eye"
    },
    {
        "name": "Escaped Quote Leakage",
        "input": "\",\n\"Astronauts have confirmed that the Great Wall is difficult to see even from low Earth orbit due to its size and color",
        "expected": "Astronauts have confirmed that the Great Wall is difficult to see even from low Earth orbit due to its size and color"
    },
    {
        "name": "Mixed Structural Fragments",
        "input": "{\n\"verdict\": \"FAKE\",\n\"analysis\": \"The claim is false because...\",\n\"confidence_score\": 1.0\n}",
        "expected": "The claim is false because..."
    }
]

print("--- Grounding Sanitizer Isolation Test ---")
for tc in test_cases:
    result = sanitize_grounding_text(tc["input"])
    status = "PASS" if result == tc["expected"] else "FAIL"
    print(f"[{status}] {tc['name']}")
    if status == "FAIL":
        print(f"  Input: {tc['input']!r}")
        print(f"  Expected: {tc['expected']!r}")
        print(f"  Result:   {result!r}")
print("------------------------------------------")
