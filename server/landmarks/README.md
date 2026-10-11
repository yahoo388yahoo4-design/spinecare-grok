# Optional SpineCare landmark service

This small reference service demonstrates the app's optional remote-analysis API. The app still performs MediaPipe inference locally and can run without this service or an internet connection. The server receives **landmark coordinates only**, not camera frames, and returns a technical visibility summary. It is not a medical service and does not assess spinal alignment, nerve compression, disc disease, lesions, exercise safety, or rehabilitation progress.

## Run on a trusted computer

Python 3.10+ is recommended.

```sh
python -m venv .venv
# macOS/Linux
source .venv/bin/activate
# Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
export SPINECARE_SERVER_USER='choose-a-user'
export SPINECARE_SERVER_PASSWORD='use-a-long-random-password'
uvicorn app:app --host 0.0.0.0 --port 8000
```

In Windows PowerShell, set variables with `$env:SPINECARE_SERVER_USER='...'` and `$env:SPINECARE_SERVER_PASSWORD='...'`.

In SpineCare Settings, set the server URL to `http://<private-LAN-IP>:8000`, the username/password above, and endpoint `/analyze/pose`. Enable remote enhancement, save settings, then test the connection. To use plain HTTP, the user must explicitly enable the insecure-LAN option. Only use that option on a trusted private network: Basic authentication is not encrypted over HTTP. For any traffic crossing an untrusted network, deploy behind HTTPS with a valid certificate. Do not expose this development server directly to the public internet.

## API contract

- `GET /health` — authenticated; returns service status.
- `POST /analyze/pose` — authenticated JSON: `{ "landmarks": [{"x":0.1,"y":0.2,"z":0.0,"visibility":0.9}], "client":"spinecare-mobile", "schemaVersion":1 }`.
- The response includes a non-clinical visibility summary. No input payloads are written to application storage.

Use a firewall and a dedicated account. Change credentials before use. This sample is a starting point, not a production security review.
