'use strict';
// Verifica o controle dividido no navegador sem abrir uma janela visível.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP', 'TMP', 'TMPDIR']) assert.equal(path.resolve(process.env[key]), path.resolve(campaign, 'scratch'));
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38132');
const evidence = { checks: [], errors: [] };
async function language(page, value) {
  await page.waitForFunction(value => document.getElementById('l')?.value === value &&
    window.Shiny?.shinyapp?.$inputValues.l === value && document.documentElement.lang === ({English:'en',Castellano:'es','中文':'zh-CN','Português':'pt-BR'}[value]), value);
}
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const width of [1440, 390, 320]) {
      const page = await browser.newPage({ locale: 'pt-BR', viewport: { width, height: 900 } });
      page.on('pageerror', error => evidence.errors.push(String(error)));
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.l, null, { timeout: 60000 });
      const button = page.locator('#language_toggle');
      const toggle = page.locator('#language_menu_toggle');
      const menu = page.locator('#language_menu');
      const english = menu.locator('[data-language="English"]');
      const portuguese = menu.locator('[data-language="Português"]');
      assert.equal(await button.textContent(), 'English');
      await language(page, 'Português');
      assert.equal(await menu.isVisible(), false);
      await toggle.click();
      assert.equal(await toggle.getAttribute('aria-expanded'), 'true');
      assert.equal(await menu.isVisible(), true);
      assert.deepEqual(await menu.locator('button > span').allTextContents(), JSON.parse(fs.readFileSync(path.join(__dirname,'../../config/languages.json'),'utf8')).map(item=>item.value));
      await language(page, 'Português');
      await page.keyboard.press('Escape');
      assert.equal(await menu.isVisible(), false);
      assert.equal(await toggle.getAttribute('aria-expanded'), 'false');
      assert.equal(await toggle.evaluate(node => node === document.activeElement), true);
      await button.click();
      await language(page, 'English');
      assert.equal(await button.textContent(), 'English');
      assert.equal(await page.locator('[data-wlv-label="tab_name.about"]').first().textContent(), 'About');
      await toggle.click();
      await portuguese.click();
      await language(page, 'Português');
      assert.equal(await button.textContent(), 'Português');
      assert.equal(await menu.isVisible(), false);
      assert.equal(await portuguese.getAttribute('aria-checked'), 'true');
      await toggle.focus();
      await page.keyboard.press('ArrowDown');
      assert.equal(await portuguese.evaluate(node => node === document.activeElement), true);
      await page.keyboard.press('Home');
      assert.equal(await english.evaluate(node => node === document.activeElement), true);
      await page.keyboard.press('ArrowDown');
      assert.equal(await menu.locator('[data-language="Castellano"]').evaluate(node => node === document.activeElement), true);
      await page.keyboard.press('End');
      assert.equal(await menu.locator('[data-language="ไทย"]').evaluate(node => node === document.activeElement), true);
      await page.keyboard.press('Home');
      await page.keyboard.press('Enter');
      await language(page, 'English');
      assert.equal(await menu.isVisible(), false);
      await toggle.click();
      assert.equal(await menu.locator('[aria-disabled="true"]').count(), 0);
      for (const [name,heading] of [['Castellano','El trabajo detrás de la economía mundial.'],['中文','世界经济背后的劳动。']]) {
        if (!await menu.isVisible()) await toggle.click();
        await menu.locator('[data-language="'+name+'"]').click();
        await language(page,name);
        await page.waitForFunction(text=>document.querySelector('[data-wlv-label="about2.title"]').textContent===text,heading);
        assert.equal(await button.textContent(),name);
      }
      await page.reload();
      await language(page,'中文');
      assert.equal(await button.textContent(),'中文');
      await toggle.click();
      await page.screenshot({ path: path.join(campaign, 'results', 'language-menu-' + width + '.png') });
      const geometry = await page.locator('#wlv-language').evaluate(node => {
        const bounds = node.getBoundingClientRect();
        const brand = document.querySelector('.wlv-brand').getBoundingClientRect();
        const menu = document.getElementById('language_menu').getBoundingClientRect();
        return { left: bounds.left, right: bounds.right, brandRight: brand.right, menuLeft: menu.left,
          menuRight: menu.right, scrollWidth: document.documentElement.scrollWidth };
      });
      assert.ok(geometry.left >= geometry.brandRight && geometry.right <= width, JSON.stringify(geometry));
      assert.ok(geometry.menuLeft >= 0 && geometry.menuRight <= width && geometry.scrollWidth <= width, JSON.stringify(geometry));
      await page.locator('#settings_toggle').click();
      assert.equal(await menu.isVisible(), false);
      evidence.checks.push({ width, geometry, language: await page.locator('html').getAttribute('lang') });
      await page.close();
    }
    assert.deepEqual(evidence.errors, []);
    fs.writeFileSync(path.join(campaign, 'results', 'language-menu-check.json'), JSON.stringify(evidence, null, 2), 'utf8');
    console.log(JSON.stringify(evidence));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
