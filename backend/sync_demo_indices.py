import json
import os

json_path = r'c:\Users\User\Documents\Gemini3Pro\frontend\assets\data\demo_lemon_analysis.json'

with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

analysis_text = data['analysis']
supports = data['grounding_supports']

print(f"Analysis Length: {len(analysis_text)}")

for i, support in enumerate(supports):
    segment = support['segment']
    text_to_find = segment['text']
    
    # In JSON, \n is literal, in Python string it's a newline.
    # But when we read from JSON, it's already a single char.
    # However, sometimes the text in the segment might have escaped newlines or other differences.
    
    # Try to find the text
    index = analysis_text.find(text_to_find)
    if index != -1:
        segment['start_index'] = index
        segment['end_index'] = index + len(text_to_find)
        print(f"Segment {i} found at {index}-{index + len(text_to_find)}")
    else:
        # Try to find a partial match if literal match fails (to see what's wrong)
        clean_text = text_to_find.replace('\\n', '\n')
        index = analysis_text.find(clean_text)
        if index != -1:
            segment['start_index'] = index
            segment['end_index'] = index + len(clean_text)
            segment['text'] = clean_text # Sync the text too
            print(f"Segment {i} found with cleaned text at {index}-{index + len(clean_text)}")
        else:
            print(f"Segment {i} NOT FOUND: '{text_to_find[:30]}...'")
            # If it's a markdown bullet issue, try stripping bullets
            stripped = text_to_find.strip('* ').strip()
            index = analysis_text.find(stripped)
            if index != -1:
                segment['start_index'] = index
                segment['end_index'] = index + len(stripped)
                segment['text'] = stripped
                print(f"Segment {i} found after stripping at {index}-{index + len(stripped)}")

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=4)

print("Finished resyncing indices.")
