import requests
import json

try:
    response = requests.get('http://localhost:4040/api/tunnels')
    data = response.json()
    public_url = data['tunnels'][0]['public_url']
    print("\n" + "="*50)
    print(f"YOUR URL: {public_url}")
    print("="*50 + "\n")
except Exception as e:
    print(f"Error: {e}")
