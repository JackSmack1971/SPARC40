# tests

Guidelines for tests in this directory:

- Use async/await for I/O operations.
- Never hardcode API keys; use environment variables.
- Validate inputs before processing.
- Include timeout and retry logic for API calls.
- Use try/except blocks with custom exceptions.
- Keep helper functions under 30 lines and include type hints.
- Aim for at least 80% coverage on new code.
