import os, json, sqlite3, hashlib, hmac, secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

import jwt
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

DB_PATH = os.getenv('DB_PATH', '/data/app.db')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'CHANGE-ME-NOW')
JWT_SECRET = os.getenv('JWT_SECRET', 'CHANGE-ME-TO-A-LONG-RANDOM-SECRET')
JWT_ISSUER = 'currency-market-api'
TOKEN_HOURS = int(os.getenv('TOKEN_HOURS', '24'))
CORS_ORIGINS = [x.strip() for x in os.getenv('CORS_ORIGINS', '*').split(',') if x.strip()]

app = FastAPI(title='Currency Market API', version='1.0.0')
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=['GET','POST','PUT','OPTIONS'],
    allow_headers=['*'],
)

SEED_STATE: dict[str, Any] = {
    'partner_code': '1234',
    'currencies': [
        {'code':'USD','title':'دلار آمریکا','flag':'🇺🇸','country':'آمریکا','cash':True,'remittance':True,'cashOrder':1,'remitOrder':1},
        {'code':'EUR','title':'یورو','flag':'🇪🇺','country':'اروپا','cash':True,'remittance':False,'cashOrder':2,'remitOrder':999},
        {'code':'AED','title':'درهم امارات','flag':'🇦🇪','country':'امارات','cash':True,'remittance':False,'cashOrder':3,'remitOrder':999},
        {'code':'GBP','title':'پوند انگلیس','flag':'🇬🇧','country':'انگلیس','cash':True,'remittance':True,'cashOrder':4,'remitOrder':3},
        {'code':'TRY','title':'لیر ترکیه','flag':'🇹🇷','country':'ترکیه','cash':True,'remittance':False,'cashOrder':5,'remitOrder':999},
        {'code':'CAD','title':'دلار کانادا','flag':'🇨🇦','country':'کانادا','cash':False,'remittance':True,'cashOrder':999,'remitOrder':2},
    ],
    'methods': [
        {'id':1,'country':'آمریکا','flag':'🇺🇸','currency':'USD','title':'واریز به حساب','order':1},
        {'id':2,'country':'آمریکا','flag':'🇺🇸','currency':'USD','title':'Cash','order':2},
        {'id':3,'country':'آمریکا','flag':'🇺🇸','currency':'USD','title':'Money Order','order':3},
        {'id':4,'country':'آمریکا','flag':'🇺🇸','currency':'USD','title':'Zelle','order':4},
        {'id':5,'country':'آمریکا','flag':'🇺🇸','currency':'USD','title':'Wire','order':5},
        {'id':6,'country':'کانادا','flag':'🇨🇦','currency':'CAD','title':'Cash Toronto','order':1},
        {'id':7,'country':'کانادا','flag':'🇨🇦','currency':'CAD','title':'Cash Vancouver','order':2},
        {'id':8,'country':'کانادا','flag':'🇨🇦','currency':'CAD','title':'حواله ایمیلی','order':3},
        {'id':9,'country':'کانادا','flag':'🇨🇦','currency':'CAD','title':'واریز به حساب','order':4},
        {'id':10,'country':'کانادا','flag':'🇨🇦','currency':'CAD','title':'Wire','order':5},
        {'id':11,'country':'انگلیس','flag':'🇬🇧','currency':'GBP','title':'Cash London','order':1},
        {'id':12,'country':'انگلیس','flag':'🇬🇧','currency':'GBP','title':'واریز به حساب','order':2},
        {'id':13,'country':'انگلیس','flag':'🇬🇧','currency':'GBP','title':'FCA','order':3},
    ],
    'rates': [
        {'kind':'cash','key':'USD','audience':'retail','buy':103000,'sell':104000},
        {'kind':'cash','key':'EUR','audience':'retail','buy':112000,'sell':113200},
        {'kind':'cash','key':'AED','audience':'retail','buy':28050,'sell':28300},
        {'kind':'cash','key':'GBP','audience':'retail','buy':131000,'sell':132500},
        {'kind':'cash','key':'USD','audience':'partner','buy':103500,'sell':103800},
        {'kind':'remittance','key':'4','audience':'retail','buy':103400,'sell':104400},
        {'kind':'remittance','key':'6','audience':'retail','buy':75400,'sell':76200},
        {'kind':'remittance','key':'4','audience':'partner','buy':103600,'sell':103900},
        {'kind':'remittance','key':'6','audience':'partner','buy':75800,'sell':76000},
    ],
    'regional': [
        {'from':'تهران','to':'ترکیه','currency':'USD','audience':'retail','base':10000,'dest':9980},
        {'from':'تهران','to':'دبی','currency':'USD','audience':'retail','base':10000,'dest':9980},
        {'from':'سلیمانیه','to':'تهران','currency':'USD','audience':'retail','base':10000,'dest':10020},
        {'from':'تهران','to':'دبی','currency':'USD','audience':'partner','base':10000,'dest':9975},
    ],
    'meta': {'valid_minutes': 15, 'updated_at': None}
}



_MOJIBAKE_MARKERS = ('Ø','Ù','Û','Ú','ð','Ÿ','â')

def repair_mojibake_text(value: str) -> str:
    """Repair common UTF-8 text that was accidentally decoded as Windows-1252."""
    if not any(marker in value for marker in _MOJIBAKE_MARKERS):
        return value
    try:
        repaired = value.encode('cp1252').decode('utf-8')
    except (UnicodeEncodeError, UnicodeDecodeError):
        return value
    before = sum(value.count(m) for m in _MOJIBAKE_MARKERS)
    after = sum(repaired.count(m) for m in _MOJIBAKE_MARKERS)
    return repaired if after < before else value

def repair_mojibake(value: Any) -> tuple[Any, bool]:
    if isinstance(value, str):
        repaired = repair_mojibake_text(value)
        return repaired, repaired != value
    if isinstance(value, list):
        changed = False
        out = []
        for item in value:
            fixed, did_change = repair_mojibake(item)
            out.append(fixed)
            changed = changed or did_change
        return out, changed
    if isinstance(value, dict):
        changed = False
        out = {}
        for key, item in value.items():
            fixed, did_change = repair_mojibake(item)
            out[key] = fixed
            changed = changed or did_change
        return out, changed
    return value, False

class LoginBody(BaseModel):
    password: str

class PartnerBody(BaseModel):
    code: str

class StateBody(BaseModel):
    partner_code: str
    currencies: list[dict[str, Any]]
    methods: list[dict[str, Any]]
    rates: list[dict[str, Any]]
    regional: list[dict[str, Any]]
    meta: Optional[dict[str, Any]] = None


def db() -> sqlite3.Connection:
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute('PRAGMA journal_mode=WAL')
    con.execute('PRAGMA synchronous=NORMAL')
    return con


def init_db() -> None:
    with db() as con:
        con.execute('CREATE TABLE IF NOT EXISTS app_state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL, updated_at TEXT NOT NULL)')
        row = con.execute('SELECT id FROM app_state WHERE id=1').fetchone()
        if not row:
            now = datetime.now(timezone.utc).isoformat()
            s = json.loads(json.dumps(SEED_STATE, ensure_ascii=False))
            s['meta']['updated_at'] = now
            con.execute('INSERT INTO app_state(id,json,updated_at) VALUES(1,?,?)', (json.dumps(s, ensure_ascii=False), now))
        else:
            stored = con.execute('SELECT json FROM app_state WHERE id=1').fetchone()
            if stored:
                current = json.loads(stored['json'])
                repaired, changed = repair_mojibake(current)
                if changed:
                    now = datetime.now(timezone.utc).isoformat()
                    repaired.setdefault('meta', {})['updated_at'] = now
                    con.execute('UPDATE app_state SET json=?, updated_at=? WHERE id=1', (json.dumps(repaired, ensure_ascii=False), now))


def load_state() -> dict[str, Any]:
    with db() as con:
        row = con.execute('SELECT json FROM app_state WHERE id=1').fetchone()
    if not row:
        raise RuntimeError('state missing')
    return json.loads(row['json'])


def save_state(state: dict[str, Any]) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    state.setdefault('meta', {})['updated_at'] = now
    with db() as con:
        con.execute('UPDATE app_state SET json=?, updated_at=? WHERE id=1', (json.dumps(state, ensure_ascii=False), now))
    return state


def token(role: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({'iss': JWT_ISSUER, 'sub': role, 'iat': now, 'exp': now + timedelta(hours=TOKEN_HOURS), 'nonce': secrets.token_hex(4)}, JWT_SECRET, algorithm='HS256')


def role_from_auth(authorization: Optional[str]) -> str:
    if not authorization:
        return 'retail'
    if not authorization.lower().startswith('bearer '):
        raise HTTPException(401, 'Invalid authorization header')
    raw = authorization.split(' ', 1)[1].strip()
    try:
        payload = jwt.decode(raw, JWT_SECRET, algorithms=['HS256'], issuer=JWT_ISSUER)
        role = payload.get('sub')
        if role not in ('admin','partner'):
            raise ValueError('role')
        return role
    except Exception:
        raise HTTPException(401, 'Invalid or expired token')


def public_view(state: dict[str, Any], audience: str) -> dict[str, Any]:
    return {
        'currencies': state['currencies'],
        'methods': state['methods'],
        'rates': [x for x in state['rates'] if x.get('audience') == audience],
        'regional': [x for x in state['regional'] if x.get('audience') == audience],
        'meta': state.get('meta', {}),
    }

@app.on_event('startup')
def startup() -> None:
    init_db()

@app.get('/health')
def health() -> dict[str, str]:
    return {'status':'ok'}

@app.post('/api/v1/admin/login')
def admin_login(body: LoginBody) -> dict[str, str]:
    if not hmac.compare_digest(body.password, ADMIN_PASSWORD):
        raise HTTPException(401, 'Wrong password')
    return {'token': token('admin')}

@app.post('/api/v1/partner/login')
def partner_login(body: PartnerBody) -> dict[str, str]:
    state = load_state()
    if not hmac.compare_digest(body.code, str(state.get('partner_code',''))):
        raise HTTPException(401, 'Wrong partner code')
    return {'token': token('partner')}

@app.get('/api/v1/state')
def get_state(authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    role = role_from_auth(authorization)
    state = load_state()
    if role == 'admin':
        return state
    return public_view(state, 'partner' if role == 'partner' else 'retail')

@app.put('/api/v1/admin/state')
def put_state(body: StateBody, authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    if role_from_auth(authorization) != 'admin':
        raise HTTPException(403, 'Admin only')
    state = body.model_dump()
    return save_state(state)
