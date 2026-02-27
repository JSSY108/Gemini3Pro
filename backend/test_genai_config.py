from google.genai import types

try:
    config = types.GenerateContentConfig(max_remote_calls=3)
    print("SUCCESS")
except Exception as e:
    print(f"FAILED: {e}")
