import pytest
import sys
import os
from unittest.mock import patch, MagicMock

# ── Block heavy imports before main.py loads ──────────────────────────────────
sys.modules['firebase_admin'] = MagicMock()
sys.modules['firebase_admin.credentials'] = MagicMock()
sys.modules['firebase_admin.firestore'] = MagicMock()
sys.modules['firebase_admin.storage'] = MagicMock()
sys.modules['ai'] = MagicMock()
sys.modules['pdf_generator'] = MagicMock()
sys.modules['config'] = MagicMock()

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Health endpoint returns 200"""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'ok'

def test_analyze_no_video(client):
    """Analyze route returns 400 when no video provided"""
    response = client.post('/analyze')
    assert response.status_code == 400
    data = response.get_json()
    assert data['status'] == 'error'
    assert 'No video file provided' in data['message']

def test_register_missing_fields(client):
    """Register route returns 400 when email or UID missing"""
    response = client.post('/register',
                           json={'name': 'Test Doctor'},
                           content_type='application/json')
    assert response.status_code == 400
    data = response.get_json()
    assert data['status'] == 'error'
    assert 'Missing email or UID' in data['message']

def test_register_valid(client):
    """Register route returns 200 with valid data"""
    response = client.post('/register',
                           json={
                               'email': 'doctor@test.com',
                               'uid': 'test-uid-123',
                               'name': 'Dr. Test'
                           },
                           content_type='application/json')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'success'