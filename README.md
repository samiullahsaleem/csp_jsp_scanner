# JSP Security Checker

### Overview

JSP Security Checker is a robust Bash script that ensures JSP files in your project meet modern security standards. It helps detect and report issues such as:

- Missing nonce attributes in `<script>` tags and inline JavaScript event handlers.
- Unsafe inline CSS in HTML tags or JavaScript.
- Deprecated `createHR` or `createHROnload` functions.
- Insecure inclusions of `hr.js`.
- Include relationships between JSP files.

This tool is specifically designed for teams working on JSP-based projects. It is ideal for identifying and resolving issues during development before committing code to Git repositories.

---

### Features

1. **Security Violation Detection**:
   - Identifies inline styles and event handlers missing nonce attributes.
   - Checks `<script>` tags for missing nonce attributes.
   - Flags insecure JavaScript style assignments.

2. **Code Quality Checks**:
   - Detects usage of outdated `hr.js` and `createHR` or `createHROnload` functions.

3. **Git Integration**:
   - Automatically analyzes modified JSP files in the current Git repository.

4. **Recursive Include Resolution**:
   - Processes included JSP files (`<%@ include ... %>` and `<jsp:include ... />`) recursively to ensure comprehensive analysis.

5. **Interactive Reporting**:
   - Displays detailed issue reports with line numbers and file paths.
   - Maps include relationships for better understanding of file dependencies.

---

### How It Works

#### Script Workflow:

1. **Initialization**:
   - Locates the `WebContent` directory relative to the script's execution path.
   - If the directory is not found, the script terminates with an error.

2. **File Detection**:
   - Identifies changed JSP files using `git diff`. If no changes are detected, it processes all JSP files within the `WebContent` directory.

3. **Security Checks**:
   - Scans each JSP file line-by-line for:
     - Missing nonce attributes in `<script>` tags or inline event handlers.
     - Inline CSS usage in HTML and JavaScript.
     - Inclusion of `hr.js` and deprecated `createHR` functions.

4. **Include Relationships**:
   - Recursively resolves and processes JSP files included using `<%@ include ... %>` or `<jsp:include ... />`.

5. **Reporting**:
   - Provides a clear, color-coded report of detected violations and file relationships.

---

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-repo/jsp-security-checker.git
   cd jsp-security-checker
