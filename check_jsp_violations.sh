# Author: Sami Ullah Saleem
# Email: ssaleem02@i2cinc.com
#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Find the WebContent directory relative to where the script is run
BASE_DIR=$(find "$(pwd)" -type d -name "WebContent" | head -n 1)

# If WebContent is not found, exit with an error
if [ -z "$BASE_DIR" ]; then
  echo -e "${RED}Error: WebContent directory not found.${NC}"
  exit 1
fi

echo -e "${BLUE}Base directory for WebContent: $BASE_DIR${NC}"

# Array to store all processed files to avoid duplicates
declare -A processed_files
# Array to store include relationships
declare -A include_relationships

# Function to normalize file path (absolute path)
normalize_path() {
    local path=$1
    echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
}

# Function to find included JSP files
find_includes() {
    local file=$1
    local base_dir=$(dirname "$file")
    
    # Find both <%@ include file="..." %> and <jsp:include page="..." /> patterns
    local includes=$(grep -E '<%@[[:space:]]*include[[:space:]]+file="([^"]+)"' "$file" | sed -E 's/.*file="([^"]+)".*/\1/')
    local jsp_includes=$(grep -E '<jsp:include[[:space:]]+page="([^"]+)"' "$file" | sed -E 's/.*page="([^"]+)".*/\1/')
    
    # Store include relationships
    for include in $includes $jsp_includes; do
        # Remove leading and trailing whitespace
        include=$(echo "$include" | xargs)
        [ -z "$include" ] && continue
        
        # Handle different path formats
        if [[ "$include" == /* ]]; then
            include="WebContent$include"
        else
            include="$BASE_DIR/$include"  # Ensure the relative path is resolved within the WebContent directory
        fi
        
        include=$(normalize_path "$include")
        include_relationships["$file"]+="$include "
    done
    
    # Return the includes for processing
    echo "$includes $jsp_includes"
}

# Function to check if a line contains a proper nonce attribute
has_valid_nonce() {
    local line=$1
    [[ $line =~ nonce=\"\<%=\(String\)\ request\.getAttribute\(Constants\.REQUEST_ATTRIBUTE_KEY_NONCE\)\%\>\" ]] || \
    [[ $line =~ nonce=\"\<%=\(String\)\ request\.getAttribute\(\"nonce\"\)\%\>\" ]]
}

# Function to check if style attribute is in HTML (not in JavaScript)
is_html_style_attribute() {
    local line=$1
    local pattern='<[^>]*style[[:space:]]*=[[:space:]]*"[^"]*"'
    [[ $line =~ $pattern ]]
}

# New function to check for style assignment in JavaScript
is_javascript_style_assignment() {
    local line=$1
    local pattern='\.style\.background[ ]*=[ ]*["'\''][^"'\'']*["'\'']'
    [[ $line =~ $pattern ]]
}

# Function to check if a line contains an event handler
is_event_handler() {
    local line=$1
    local pattern='<[^>]*\son[a-zA-Z]+[[:space:]]*=[[:space:]]*["\x27][^"\x27]*["\x27]'
    [[ $line =~ $pattern ]]
}

# Function to check if a line contains 'createHR' or 'createHROnload' functions
contains_createHR_function() {
    local line=$1
    [[ $line =~ createHR\(\) || $line =~ createHROnload\(\) ]]
}

# Function to check if the line contains hr.js
contains_hr_js() {
    local line=$1
    [[ $line =~ hr\.js ]]
}

# Function to display include relationships
display_include_relationships() {
    echo -e "\n${BLUE}Include Relationships:${NC}"
    for parent in "${!include_relationships[@]}"; do
        echo -e "${YELLOW}Parent JSP:${NC} $parent"
        for included in ${include_relationships[$parent]}; do
            echo -e "  ${GREEN}├── Includes:${NC} $included"
        done
    done
}

# Function to check a file for security violations
check_file() {
    local file=$1
    local violations_found=false
    
    # Skip if file doesn't exist or already processed
    [ ! -f "$file" ] && return
    [ -n "${processed_files[$file]}" ] && return  # Skip if already processed (no output)

    # Mark file as processed
    processed_files[$file]=1

    # Debug statement to confirm file is being processed (this part will now be skipped for already processed files)
    echo -e "${YELLOW}Checking $file...${NC}"
    
    # Indicate that this file runs on its included files
    if [ -n "${include_relationships[$file]}" ]; then
        echo -e "${BLUE}✓ This file includes:${NC} ${include_relationships[$file]}"
    fi

    # Check for hr.js inclusion
    while IFS= read -r line; do
        line_number=$(echo "$line" | cut -d: -f1)
        line_content=$(echo "$line" | cut -d: -f2-)
        if contains_hr_js "$line_content"; then
            if ! $violations_found; then
                echo -e "${RED}❌ hr.js detected:${NC}"
                violations_found=true
            fi
            echo "Line $line_number: $line_content"
        fi
    done < <(egrep -n 'hr\.js' "$file")

    # Check for inline JavaScript event handlers without nonce
    while IFS= read -r line; do
        line_number=$(echo "$line" | cut -d: -f1)
        line_content=$(echo "$line" | cut -d: -f2-)
        if is_event_handler "$line_content" && ! has_valid_nonce "$line_content"; then
            if ! $violations_found; then
                echo -e "${RED}❌ Inline JavaScript event handlers detected:${NC}"
                violations_found=true
            fi
            echo "Line $line_number: $line_content"
        fi
    done < <(egrep -n '<[^>]*\son[a-zA-Z]+\s*=' "$file")

    # Check for script tags without nonce
    while IFS= read -r line; do
        line_number=$(echo "$line" | cut -d: -f1)
        line_content=$(echo "$line" | cut -d: -f2-)
        if ! has_valid_nonce "$line_content"; then
            if [[ "$line_content" =~ \<script.*nonce= ]]; then
                continue  # Skip if any nonce attribute is present
            fi
            if ! $violations_found; then
                echo -e "${RED}❌ Script tags missing nonce attribute:${NC}"
                violations_found=true
            fi
            echo "Line $line_number: $line_content"
        fi
    done < <(grep -n '<script' "$file")

    # Check for inline CSS in HTML tags only (not in JavaScript)
    while IFS= read -r line; do
        line_number=$(echo "$line" | cut -d: -f1)
        line_content=$(echo "$line" | cut -d: -f2-)
        if is_html_style_attribute "$line_content"; then
            if ! $violations_found; then
                echo -e "${RED}❌ Inline CSS in HTML detected:${NC}"
                violations_found=true
            fi
            echo "Line $line_number: $line_content"
        fi
    done < <(egrep -n '<[^>]*style\s*=' "$file")

    # Check for JavaScript style assignments
    while IFS= read -r line; do
        line_number=$(echo "$line" | cut -d: -f1)
        line_content=$(echo "$line" | cut -d: -f2-)
        if is_javascript_style_assignment "$line_content"; then
            if ! $violations_found; then
                echo -e "${RED}❌ Inline CSS in JavaScript detected:${NC}"
                violations_found=true
            fi
            echo "Line $line_number: $line_content"
        fi
    done < <(egrep -n '\.style\.background' "$file")

    # Check for createHR or createHROnload functions
    while IFS= read -r line; do
        line_number=$(echo "$line" | cut -d: -f1)
        line_content=$(echo "$line" | cut -d: -f2-)
        if contains_createHR_function "$line_content"; then
            if ! $violations_found; then
                echo -e "${RED}❌ createHR or createHROnload functions detected:${NC}"
                violations_found=true
            fi
            echo "Line $line_number: $line_content"
        fi
    done < <(egrep -n 'createHR\(\)|createHROnload\(\)' "$file")

    if ! $violations_found; then
        echo -e "${GREEN}✓ No security violations found${NC}"
    fi

    # Find and immediately check included files (recursively process includes)
    local included_files=$(find_includes "$file")
    for included_file in $included_files; do
        # Skip if already processed
        if [ -n "${processed_files[$included_file]}" ]; then
            continue
        fi
        
        # Resolve the full path of the included file
        # If the include is an absolute path (starts with /), prepend WebContent to it
        if [[ "$included_file" == /* ]]; then
            included_file="$BASE_DIR$included_file"  # Absolute path for file starting with /
        else
            included_file="$BASE_DIR/$included_file"  # Relative path
        fi

        # Normalize the path to handle symlinks and inconsistencies
        included_file=$(normalize_path "$included_file")
        
        # Immediately process the included file
        check_file "$included_file"
    done
}

# Function to recursively find all JSP files within WebContent directory
find_jsp_files() {
    find "$BASE_DIR" -type f -iname "*.jsp"
}

# Main execution
echo "JSP Security Checker v1.0"
echo "========================="

# Get list of changed JSP files from git
changed_files=$(git diff --name-only HEAD | grep -E "\.jsp$")

# If no files found, check all JSP files in the WebContent directory
if [ -z "$changed_files" ]; then
    changed_files=$(find_jsp_files)
fi

# Process each changed file or all JSP files
for file in $changed_files; do
    check_file "$file"
done

display_include_relationships
# Wait for user input before exiting
echo -e "${BLUE}\nPress any key to exit...${NC}"
read -n 1 -s

