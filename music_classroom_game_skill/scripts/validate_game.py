#!/usr/bin/env python3
from __future__ import annotations
import argparse, asyncio, json, re
from pathlib import Path
from urllib.parse import urlparse

from playwright.async_api import async_playwright


def static_checks(path: Path):
    text = path.read_text(encoding='utf-8', errors='replace')
    return {
        'doctype_html': '<!doctype html' in text.lower(),
        'viewport': 'name="viewport"' in text or "name='viewport'" in text,
        'inline_script': '<script' in text.lower(),
        'no_external_script_src': not re.search(r'<script[^>]+src=["\']https?://', text, re.I),
        'no_external_stylesheet': not re.search(r'<link[^>]+href=["\']https?://', text, re.I),
        'no_fetch_http': not re.search(r'\bfetch\s*\(\s*["\']https?://', text, re.I),
        'no_xhr_http': not ('XMLHttpRequest' in text and ('http://' in text or 'https://' in text)),
        'has_user_action': bool(re.search(r'<button\b|pointerdown|click', text, re.I)),
        'not_empty': len(text) > 3000,
    }


async def browser_checks(path: Path):
    errors, requests, results = [], [], {}
    html = path.read_text(encoding='utf-8', errors='replace')
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            executable_path='/usr/bin/chromium',
            args=['--autoplay-policy=no-user-gesture-required']
        )
        for label, viewport in [('desktop', {'width':1280,'height':720}), ('mobile', {'width':390,'height':844})]:
            page = await browser.new_page(viewport=viewport)
            local_errors, local_requests = [], []
            page.on('pageerror', lambda exc, a=local_errors: a.append(str(exc)))
            page.on('console', lambda msg, a=local_errors: a.append('console:'+msg.text) if msg.type=='error' else None)
            def req_listener(req, a=local_requests):
                u = urlparse(req.url)
                if u.scheme in ('http','https'):
                    a.append(req.url)
            page.on('request', req_listener)
            await page.set_content(html, wait_until='load')
            await page.wait_for_timeout(250)
            dims = await page.evaluate("""() => ({
              sw: document.documentElement.scrollWidth,
              cw: document.documentElement.clientWidth,
              sh: document.documentElement.scrollHeight,
              buttons: document.querySelectorAll('button').length,
              title: document.title,
              selfTest: window.__musicGameMeta && window.__musicGameMeta.selfTest ? window.__musicGameMeta.selfTest() : null
            })""")
            results[label] = {
                'title': dims['title'],
                'buttons': dims['buttons'],
                'horizontal_overflow_px': max(0, dims['sw']-dims['cw']),
                'self_test': dims.get('selfTest'),
                'page_errors': local_errors,
                'external_requests': local_requests,
            }
            errors.extend(f'{label}: {x}' for x in local_errors)
            requests.extend(f'{label}: {x}' for x in local_requests)
            await page.close()
        await browser.close()
    return results, errors, requests


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('html')
    args = ap.parse_args()
    path = Path(args.html).resolve()
    if not path.exists():
        print(json.dumps({'ok':False,'error':'file not found'}, ensure_ascii=False, indent=2))
        return 2
    static = static_checks(path)
    browser, errors, requests = await browser_checks(path)
    overflow_ok = all(v['horizontal_overflow_px'] <= 2 for v in browser.values())
    self_tests = [v.get('self_test') for v in browser.values() if v.get('self_test') is not None]
    self_ok = all(bool(t.get('pass')) for t in self_tests) if self_tests else True
    ok = all(static.values()) and not errors and not requests and overflow_ok and self_ok
    print(json.dumps({'ok':ok,'static':static,'browser':browser}, ensure_ascii=False, indent=2))
    return 0 if ok else 1

if __name__=='__main__':
    raise SystemExit(asyncio.run(main()))
