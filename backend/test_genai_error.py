from google import genai
import inspect

try:
    raise genai.errors.ClientError("Test message", code=429)
except Exception as e:
    print(type(e).__name__)
