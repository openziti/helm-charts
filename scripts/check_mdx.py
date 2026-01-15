#!/usr/bin/env python3
import glob
import re
import sys

def check_file(filepath):
    errors = []
    with open(filepath, 'r') as f:
        lines = f.readlines()

    in_code_block = False
    
    for i, line in enumerate(lines):
        lineStr = line.strip()
        
        # Ignore HTML comments
        if lineStr.startswith("<!--"):
            continue
            
        # Check for fenced code blocks
        if lineStr.startswith("```"):
            in_code_block = not in_code_block
            continue
            
        if in_code_block:
            continue
            
        # Check for presence of object-like pattern
        if "{" in lineStr and "}" in lineStr:
            # Ignore if already wrapped in backticks
            # We can simply remove all backticked content and see if braces remain
            
            # Remove content between backticks (lazy match)
            # This regex replaces `...` with empty string
            clean_line = re.sub(r'`[^`]*`', '', lineStr)
            
            # If braces still exist in the "clean" line, it might be an issue.
            
            if "{" in clean_line and "}" in clean_line:
                # Filter out some common benign cases like template vars {{ .Values... }}
                if "{{" in clean_line or "}}" in clean_line:
                    continue
                
                # Filter out escaped braces \{ \}
                if "\\{" in clean_line or "\\}" in clean_line:
                     # This is a weak check, strictly we should remove escaped ones.
                     # Let's try to remove escaped ones.
                     clean_line = clean_line.replace("\\{", "").replace("\\}", "")
                     if "{" not in clean_line or "}" not in clean_line:
                         continue

                errors.append(f"{filepath}:{i+1}: {lineStr}")

    return errors

def main():
    if len(sys.argv) > 1:
        files = sys.argv[1:]
    else:
        # Default to checking generated READMEs
        files = glob.glob('charts/*/README.md')

    all_errors = []
    
    for f in files:
        errs = check_file(f)
        all_errors.extend(errs)
        
    if all_errors:
        print("Found potentially MDX-unsafe content (naked braces not wrapped in backticks):")
        for e in all_errors:
            print(e)
        sys.exit(1)
    else:
        print("No MDX issues found.")
        sys.exit(0)

if __name__ == "__main__":
    main()
