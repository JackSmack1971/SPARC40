# src

Guidelines for code in this directory:

- Use async/await for all I/O operations.
- Never hardcode API keys; read them from environment variables.
- Validate inputs before processing.
- Include timeout and retry logic for API calls.
- Use try/except blocks with custom exceptions.
- Keep each function under 30 lines and include type hints.
