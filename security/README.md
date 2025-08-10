# Security Guidelines

This directory holds security policies for different stages of the pipeline.

- Always validate user inputs before processing.
- Use try/except blocks with custom exceptions for all operations.
- Access secrets like API keys via environment variables; never hardcode them.

Subdirectories provide stage-specific details.
