# SPARC40

## Configuration

SPARC40 uses environment variables for all configuration. Set them in your shell or in a `.env` file and never hardcode secrets.

Example:

```bash
export VIDEO_API_KEY="your_api_key"
export DATABASE_URL="postgresql://user:pass@localhost:5432/db"
```

In code, read values from `os.environ` to keep credentials out of source control:

```python
import os

API_KEY = os.environ["VIDEO_API_KEY"]
```

Ensure each variable is validated before use and avoid committing `.env` files to version control.


## Deployment Notes

Deployment scripts must source API keys from environment variables and include retry logic for API calls.
