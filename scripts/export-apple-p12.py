"""Combine Apple's downloaded certificate with this machine's original CSR key."""
from pathlib import Path
import secrets
import sys
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import pkcs12

folder = Path(__file__).resolve().parent.parent/'artifacts/ios-signing'
certificate_path = Path(sys.argv[1])
raw = certificate_path.read_bytes()
certificate = (x509.load_pem_x509_certificate(raw) if raw.startswith(b'-----BEGIN')
               else x509.load_der_x509_certificate(raw))
key = serialization.load_pem_private_key((folder/'distribution-private-key.pem').read_bytes(),
    password=(folder/'private-key-password.txt').read_bytes())
if key.public_key().public_numbers() != certificate.public_key().public_numbers():
    raise SystemExit('Certificate does not match this CSR private key; no export was created.')
target = folder/'ZOVV-Distribution.p12'
if target.exists():
    raise SystemExit('P12 already exists; preserve its existing password.')
password = secrets.token_urlsafe(32).encode()
target.write_bytes(pkcs12.serialize_key_and_certificates(b'ZOVV Distribution',key,certificate,None,
    serialization.BestAvailableEncryption(password)))
(folder/'p12-password.txt').write_bytes(password)
print('P12 exported in artifacts/ios-signing; password saved locally, not printed.')
