"""
Basic tests for the FastAPI backend application.
"""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_endpoint():
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_api_endpoint():
    """Test the API info endpoint."""
    response = client.get("/api/")
    assert response.status_code == 200
    data = response.json()
    assert "hostname" in data
    assert "ip" in data
    assert "status" in data
    assert data["status"] == "active"
