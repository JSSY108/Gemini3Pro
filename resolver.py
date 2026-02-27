import os
import re

def resolve_file(path, resolution_type):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    conflicts = list(re.finditer(r'<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> teammate/main\n', content, re.DOTALL))
    if not conflicts:
        print(f"No conflicts found in {path}")
        return

    # Helper function to replace conflict based on logic
    def replacer(match):
        head_block = match.group(1)
        teammate_block = match.group(2)

        if resolution_type == 'interactive_text':
            return head_block + '\n'
            
        elif resolution_type == 'fact_check_screen':
            return head_block + '\n'

        elif resolution_type == 'source_tile':
            if 'import ' in head_block:
                return head_block + '\n' + teammate_block + '\n'
            elif 'void _showPdfDialog' in head_block:
                return teammate_block + '\n'
            elif 'SourceReliabilityBadge' in head_block:
                return head_block + '\n'
            return head_block + '\n'

        elif resolution_type == 'evidence_card':
            if 'import ' in head_block:
                return head_block + '\n' + teammate_block + '\n'
            elif 'void _showPdfDialog' in head_block:
                return teammate_block + '\n'
            elif 'SourceReliabilityBadge' in head_block:
                return head_block + '\n'
            return head_block + '\n'

        return head_block + '\n'

    resolved_content = re.sub(r'<<<<<<< HEAD\n(.*?)\n=======\n(.*?)\n>>>>>>> teammate/main\n', replacer, content, flags=re.DOTALL)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(resolved_content)
    print(f"Resolved {path}")

base_dir = r"c:\Users\User\Documents\Gemini3Pro\frontend\lib"
resolve_file(os.path.join(base_dir, "widgets", "veriscan_interactive_text.dart"), "interactive_text")
resolve_file(os.path.join(base_dir, "widgets", "source_tile.dart"), "source_tile")
resolve_file(os.path.join(base_dir, "widgets", "evidence_card.dart"), "evidence_card")
resolve_file(os.path.join(base_dir, "screens", "fact_check_screen.dart"), "fact_check_screen")
