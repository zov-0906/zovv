"""Create a CSR once; keep encrypted private key in ignored local artifacts."""
import secrets
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

folder = Path(__file__).resolve().parent.parent/'artifacts/ios-signing'
folder.mkdir(parents=True, exist_ok=True)
key_path = folder/'distribution-private-key.pem'
csr_path = folder/'ZOVV-Distribution.certSigningRequest'
if any(folder.iterdir()):
    raise SystemExit('Signing folder already contains files; preserve the existing key and CSR.')
key = rsa.generate_private_key(public_exponent=65537,key_size=2048)
password = secrets.token_urlsafe(36).encode()
key_path.write_bytes(key.private_bytes(serialization.Encoding.PEM,
    serialization.PrivateFormat.PKCS8,serialization.BestAvailableEncryption(password)))
(folder/'private-key-password.txt').write_bytes(password)
csr = x509.CertificateSigningRequestBuilder().subject_name(x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME,'ZOVV Distribution'),
])).sign(key,hashes.SHA256())
csr_path.write_bytes(csr.public_bytes(serialization.Encoding.PEM))
print('Created CSR; encrypted private key stays in artifacts/ios-signing.')
