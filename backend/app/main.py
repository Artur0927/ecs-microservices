import socket
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/")
def get_container_info():
    hostname = socket.gethostname()
    try:
        # Best effort to get IP, locally might be 127.0.0.1 or internal docker IP
        ip_address = socket.gethostbyname(hostname)
    except Exception:
        ip_address = "unknown"
    
    return {
        "hostname": hostname,
        "ip": ip_address,
        "status": "active"
    }

@app.get("/health")
def health_check():
    return {"status": "ok"}
