#!/usr/bin/env python3
"""Two real provider calls, synthetic data only. This is not account E2E.

Reads a private local env file without printing credentials. Stores only usage,
HTTP status and assertions; no prompts, completions or tokens in the receipt.
Source: https://api-docs.deepseek.com/api/create-chat-completion/
"""
import argparse
import datetime
import json
from pathlib import Path
import urllib.error
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--env-file', required=True, type=Path)
    parser.add_argument('--receipt', required=True, type=Path)
    args = parser.parse_args()
    values = {}
    for line in args.env_file.read_text().splitlines():
        key, sep, value = line.partition('=')
        if sep and not key.strip().startswith('#'):
            values[key.strip()] = value.strip().strip('"').strip("'")
    key = values.get('DEEPSEEK_API_KEY', '')
    if not key:
        raise SystemExit('Missing private DeepSeek key; no request sent')
    opener = urllib.request.build_opener(NoRedirect)
    receipt = {'at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'model': 'deepseek-flash', 'thinking': 'disabled',
               'scope': 'provider-only; synthetic profile; not real account E2E',
               'rounds': [], 'passed': False}
    messages = [{'role': 'system', 'content': 'Use the supplied tool once to answer using confirmed synthetic facts only.'},
                {'role': 'user', 'content': 'Which home city is confirmed for this synthetic traveler?'}]
    tools = [{'type': 'function', 'function': {'name': 'get_traveler_profile',
              'description': 'Read confirmed synthetic traveler profile.',
              'parameters': {'type': 'object', 'properties': {}, 'additionalProperties': False}}}]

    def request(choice):
        body = {'model': 'deepseek-flash', 'thinking': {'type': 'disabled'},
                'stream': False, 'max_tokens': 128, 'messages': messages,
                'tools': tools, 'tool_choice': choice}
        req = urllib.request.Request('https://api.deepseek.com/v1/chat/completions',
              data=json.dumps(body).encode(), headers={'Content-Type': 'application/json',
              'Authorization': 'Bearer ' + key})
        try:
            with opener.open(req, timeout=45) as response:
                data = response.read(1024 * 1024 + 1)
                if len(data) > 1024 * 1024:
                    raise ValueError('oversized_response')
                decoded = json.loads(data)
                usage = decoded.get('usage', {})
                receipt['rounds'].append({'http_status': response.status,
                    'usage': {k: usage[k] for k in ('prompt_tokens', 'completion_tokens', 'total_tokens') if k in usage}})
                return decoded['choices'][0]['message']
        except urllib.error.HTTPError as error:
            receipt['rounds'].append({'http_status': error.code})
            raise ValueError('provider_http_error') from None

    try:
        first = request({'type': 'function', 'function': {'name': 'get_traveler_profile'}})
        calls = first.get('tool_calls', [])
        assert len(calls) == 1 and calls[0]['function']['name'] == 'get_traveler_profile'
        assert json.loads(calls[0]['function']['arguments']) == {}
        messages.append({'role': 'assistant', 'content': first.get('content') or '', 'tool_calls': calls})
        messages.append({'role': 'tool', 'tool_call_id': calls[0]['id'],
                         'content': json.dumps({'home_city': 'Lisbon', 'provenance': 'manual_confirmed_synthetic'})})
        final = request('none')
        assert 'Lisbon' in (final.get('content') or '')
        assert not final.get('tool_calls')
        receipt['passed'] = True
        receipt['assertions'] = ['one valid profile tool call', 'tool result consumed', 'confirmed city in final answer']
    except Exception as error:
        receipt['error_class'] = type(error).__name__
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))
    raise SystemExit(0 if receipt['passed'] else 1)


if __name__ == '__main__':
    main()
