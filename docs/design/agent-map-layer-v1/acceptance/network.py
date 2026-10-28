"""Bounded live acceptance HTTP helper. Secrets stay in this process, never CLI args."""
import json, os, pathlib, re, sys, time, urllib.error, urllib.parse, urllib.request

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def env_values():
    path = os.environ.get('MAP_CHAIN_ENV_FILE')
    values = {}
    if path:
        for line in pathlib.Path(path).read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                k, v = line.split('=', 1)
                values[k.strip().removeprefix('export ')] = v.strip().strip('\"\'')
    for key in ['DEEPSEEK_API_KEY', 'DEEPSEEK_BASE_URL', 'DEEPSEEK_MODEL', 'XAI_API_KEY']:
        if os.environ.get(key): values[key] = os.environ[key]
    return values

def main():
    request = json.load(sys.stdin)
    values = env_values()
    service = request.get('service', 'public')
    headers = {'User-Agent': 'Roamorrow-GET294-acceptance/0.1 (+https://roamorrow.com/support)', 'Accept': 'application/json'}
    if service == 'deepseek':
        key = values.get('DEEPSEEK_API_KEY')
        if not key: raise ValueError('DEEPSEEK_API_KEY missing in selected configuration')
        url = values.get('DEEPSEEK_BASE_URL', 'https://api.deepseek.com/v1').rstrip('/') + '/chat/completions'
        target = urllib.parse.urlsplit(url)
        if target.scheme != 'https' or target.username or target.password or target.query or target.fragment:
            raise ValueError('model endpoint must be an HTTPS origin path without credentials')
        headers['Authorization'] = 'Bearer ' + key
        headers['Content-Type'] = 'application/json'
        body = request['body']
        body['model'] = values.get('DEEPSEEK_MODEL', 'deepseek-flash')
        data = json.dumps(body).encode()
    elif service == 'public':
        url = request['url']
        target = urllib.parse.urlsplit(url)
        if target.scheme != 'https' or target.hostname not in ['www.wikidata.org', 'routing.openstreetmap.de'] or target.username or target.password:
            raise ValueError('public provider host not allowed')
        data = None
    else:
        raise ValueError('unsupported live service')
    started = time.monotonic()
    try:
        with urllib.request.build_opener(NoRedirect()).open(urllib.request.Request(url, data=data, headers=headers), timeout=40 if service == 'deepseek' else 18) as response:
            raw = response.read(4_000_001)
            if len(raw) > 4_000_000: raise ValueError('upstream response exceeds limit')
            payload = json.loads(raw)
            result = {'ok': True, 'status': response.status, 'elapsed_ms': round((time.monotonic()-started)*1000), 'payload': payload, 'host': urllib.parse.urlsplit(url).hostname}
    except urllib.error.HTTPError as error:
        # No upstream body/header dump: errors may echo sensitive configuration.
        detail = ''
        try:
            payload = json.loads(error.read(16000))
            detail = str(payload.get('error', {}).get('message', ''))[:500]
            for secret in [v for k,v in values.items() if 'KEY' in k or 'TOKEN' in k]:
                if secret: detail = detail.replace(secret, '[redacted]')
        except Exception: pass
        result = {'ok': False, 'status': error.code, 'error': 'upstream_http_error', 'detail': detail, 'elapsed_ms': round((time.monotonic()-started)*1000)}
    except Exception as error:
        result = {'ok': False, 'status': None, 'error': type(error).__name__, 'elapsed_ms': round((time.monotonic()-started)*1000)}
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'ok': False, 'error': type(error).__name__}))
