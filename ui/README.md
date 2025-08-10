# UI

This directory will host high-level user interface logic.

## Coding Standards
- Limit functions to 30 lines.
- Use async/await for all I/O operations.
- Include type hints and robust error handling.
- Write tests with at least 80% coverage.

## Security Requirements
- Never hardcode API keys; use environment variables.
- Validate user inputs before processing.
- Add timeout and retry logic for API calls.
- Wrap API calls in try/except blocks with custom exceptions.
