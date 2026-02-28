import os
import re

def fix_print(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # If it contains print(, we might need to import debugPrint
    if "print(" in content:
        # replace print( with debugPrint(
        # but only if not already debugPrint( or something else
        # Simple regex: match word boundary 'print('
        new_content = re.sub(r'\bprint\(', 'debugPrint(', content)
        
        # Add import if missing
        if "debugPrint" in new_content and "import 'package:flutter/foundation.dart'" not in new_content:
            new_content = "import 'package:flutter/foundation.dart' show debugPrint;\n" + new_content

        if new_content != content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Fixed prints in {filepath}")

def main():
    files = [
        r"c:\Users\User\Documents\Gemini3Pro\frontend\lib\services\community_service.dart",
        r"c:\Users\User\Documents\Gemini3Pro\frontend\lib\screens\community_screen.dart"
    ]
    for file in files:
        fix_print(file)

if __name__ == "__main__":
    main()
