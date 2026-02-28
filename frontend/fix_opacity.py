import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix .withOpacity(x) -> .withValues(alpha: x)
    # Using regex to find withOpacity(value) and replace it
    # value can be a number, a variable, etc. Be careful with nested parentheses.
    # A simple regex for basic numbers/variables: \.withOpacity\(([^)]+)\)
    new_content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

    # Note: the above regex works well for simple things like .withOpacity(0.5) or .withOpacity(alpha)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed withOpacity in {filepath}")

def main():
    lib_dir = "c:\\Users\\User\\Documents\\Gemini3Pro\\frontend\\lib"
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                fix_file(os.path.join(root, file))

if __name__ == "__main__":
    main()
