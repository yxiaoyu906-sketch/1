from __future__ import annotations
import asyncio, json
from pathlib import Path
from urllib.parse import urlparse
from playwright.async_api import async_playwright

ROOT=Path('/mnt/data/music_classroom_game_skill')
G1=Path('/mnt/data/G1_三拍节奏改编_单文件网页版_双击即用.html')
G2=Path('/mnt/data/G2_革命练习曲触击_单文件网页版_双击即用.html')
G3=ROOT/'examples/G3_小切分侦探_单文件网页版.html'

async def load(page, path):
    errs=[]; reqs=[]
    page.on('pageerror', lambda e: errs.append(str(e)))
    page.on('console', lambda m: errs.append('console:'+m.text) if m.type=='error' else None)
    page.on('request', lambda r: reqs.append(r.url) if urlparse(r.url).scheme in ('http','https') else None)
    await page.set_content(path.read_text(encoding='utf-8',errors='replace'),wait_until='load')
    await page.wait_for_timeout(250)
    return errs,reqs

async def test_g3(browser):
    out={}
    p=await browser.new_page(viewport={'width':1280,'height':720})
    errs,reqs=await load(p,G3)
    out['self_test']=await p.evaluate('window.__musicGameMeta.selfTest()')
    await p.click('#playBtn')
    await p.wait_for_timeout(150)
    out['audio_state_after_click']=await p.evaluate("audioCtx ? audioCtx.state : 'missing'")
    first_correct=await p.evaluate('current.syncBeat')
    await p.click(f'#answers button[data-i="{first_correct}"]')
    out['first_answer']={
        'score':await p.text_content('#scoreStat'),
        'feedback':(await p.text_content('#feedback')).strip(),
        'next_enabled':not await p.is_disabled('#nextBtn')
    }
    await p.wait_for_timeout(280)
    await p.screenshot(path=str(ROOT/'tests/G3_desktop_after_answer.png'),full_page=True)
    # Finish all remaining rounds correctly.
    await p.click('#nextBtn')
    for _ in range(5):
        correct=await p.evaluate('current.syncBeat')
        await p.click(f'#answers button[data-i="{correct}"]')
        await p.click('#nextBtn')
    out['finish']={
        'result_visible':await p.is_visible('#result'),
        'final_score':await p.text_content('#finalScore'),
        'game_visible':await p.is_visible('#gameCard')
    }
    # Wrong-answer path after reset.
    await p.click('#againBtn')
    correct=await p.evaluate('current.syncBeat')
    wrong=(correct+1)%4
    await p.click(f'#answers button[data-i="{wrong}"]')
    out['wrong_path']={
        'score':await p.text_content('#scoreStat'),
        'revealed_correct':await p.locator(f'.beat[data-i="{correct}"]').evaluate("e=>e.classList.contains('correct')"),
        'revealed_wrong':await p.locator(f'.beat[data-i="{wrong}"]').evaluate("e=>e.classList.contains('wrong')")
    }
    out['desktop_errors']=errs; out['external_requests']=reqs
    await p.close()

    m=await browser.new_page(viewport={'width':390,'height':844})
    merr,mreq=await load(m,G3)
    dims=await m.evaluate("""() => ({sw:document.documentElement.scrollWidth,cw:document.documentElement.clientWidth,
      buttons:[...document.querySelectorAll('button')].filter(b=>getComputedStyle(b).display!=='none'&&b.getBoundingClientRect().height>0).map(b=>{const r=b.getBoundingClientRect();return {w:r.width,h:r.height}})})""")
    out['mobile']={
        'overflow_px':max(0,dims['sw']-dims['cw']),
        'min_button_height':min(x['h'] for x in dims['buttons']),
        'errors':merr,'external_requests':mreq
    }
    await m.screenshot(path=str(ROOT/'tests/G3_mobile.png'),full_page=True)
    await m.close()
    return out

async def test_g1(browser):
    p=await browser.new_page(viewport={'width':1280,'height':720})
    errs,reqs=await load(p,G1)
    data=await p.evaluate("""() => ({
      a:A.length,b:B.length,c:C.length,
      legal:Object.values(P).every(x=>x.on.every(v=>v>=0&&v<1)),
      slots:document.querySelectorAll('.slot').length,
      palette:document.querySelectorAll('.choice').length
    })""")
    before=await p.locator('.slotName').all_text_contents()
    await p.get_by_text('随机生成合法C版').click()
    after=await p.locator('.slotName').all_text_contents()
    await p.get_by_text('播放参考A ×2').click()
    await p.wait_for_timeout(120)
    audio_state=await p.evaluate("audioCtx ? audioCtx.state : 'missing'")
    out={'data':data,'random_changed':before!=after,'audio_state_after_click':audio_state,'errors':errs,'external_requests':reqs}
    await p.close(); return out

async def test_g2(browser):
    p=await browser.new_page(viewport={'width':1280,'height':720})
    errs,reqs=await load(p,G2)
    data=await p.evaluate("""() => ({
      leftBars:DATA.left_guides.length,
      rightEvents:DATA.right_game_events.length,
      duration:DATA.duration,
      canvas:[cv.width,cv.height],
      modes:document.querySelectorAll('#toolbar button').length
    })""")
    await p.get_by_text('左手练习').click()
    mode_after=await p.evaluate('mode')
    await p.get_by_text('▶ 开始游戏').click()
    await p.wait_for_timeout(350)
    started=await p.evaluate('started')
    overlay=await p.is_visible('#startOverlay')
    audio_state=await p.evaluate("activeAudio().paused ? 'paused' : 'playing'")
    await p.get_by_text('重新准备').click()
    reset=await p.evaluate("() => ({started,score,combo,hits,misses,overlay:getComputedStyle(document.getElementById('startOverlay')).display})")
    out={'data':data,'mode_after_click':mode_after,'started_after_click':started,'start_overlay_visible':overlay,'audio_state':audio_state,'reset':reset,'errors':errs,'external_requests':reqs}
    await p.close(); return out

async def main():
    async with async_playwright() as pw:
        browser=await pw.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--autoplay-policy=no-user-gesture-required'])
        results={
          'G1_source_smoke':await test_g1(browser),
          'G2_source_smoke':await test_g2(browser),
          'G3_generated_from_skill':await test_g3(browser)
        }
        await browser.close()
    (ROOT/'tests/qa_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(results,ensure_ascii=False,indent=2))

if __name__=='__main__': asyncio.run(main())
