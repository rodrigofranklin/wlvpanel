'use strict';
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP', 'TMP', 'TMPDIR']) assert.equal(path.resolve(process.env[key]), path.resolve(campaign, 'scratch'));
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38132');
const evidence = { views: [], errors: [], downloads: [] };
async function idle(page) {
  await page.waitForFunction(() => {
    if (document.documentElement.classList.contains('shiny-busy')) { window.explorationQuiet = 0; return false; }
    if (!window.explorationQuiet) window.explorationQuiet = performance.now();
    return performance.now() - window.explorationQuiet > 700;
  });
}
async function navigate(page, tab) {
  if (await page.locator('.navbar-toggle').isVisible()) await page.locator('.navbar-toggle').click();
  await page.locator('#main_nav a[data-value="' + tab + '"]').click();
  if (await page.locator('.navbar-toggle').isVisible()) await page.locator('.navbar-collapse').waitFor({state:'hidden'});
  await idle(page);
}
async function geometry(page) {
  return page.evaluate(() => {
    const content = document.querySelector('body > .container-fluid');
    return { width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
      contentWidth: content.clientWidth, contentScrollWidth: content.scrollWidth,
      errors: [...document.querySelectorAll('.shiny-output-error')].filter(node => node.getClientRects().length).map(node => node.textContent) };
  });
}
(async () => {
  const browser = await chromium.launch({headless:true});
  try {
    for (const [language, code] of [['Castellano','es'],['中文','zh']]) for (const width of [1440,390]) {
      const context = await browser.newContext({viewport:{width,height:1000},locale:'pt-BR',acceptDownloads:true});
      const page = await context.newPage();
      page.setDefaultTimeout(60000);
      page.on('pageerror', error => evidence.errors.push(String(error)));
      await page.goto(url,{waitUntil:'domcontentloaded'});
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.l, null, {timeout:60000});
      await page.locator('#language_menu_toggle').click();
      await page.locator('#language_menu [data-language="' + language + '"]').click();
      await page.waitForFunction(language => Shiny.shinyapp.$inputValues.l === language, language);
      await navigate(page,'country');
      await page.waitForFunction(() => document.querySelector('#wlv-country-entry')?.dataset.state==='ready',null,{timeout:60000});
      await idle(page);
      assert.match(await page.locator('#co_entry_description').textContent(), code==='es' ? /Un retrato del trabajo/ : /了解劳动/);
      assert.match(await page.locator('#co_entry_labour_chart').textContent(), code==='es' ? /Plusvalor/ : /剩余价值/);
      assert.match(await page.locator('#co_entry_more').textContent(), code==='es' ? /Mostrar más/ : /查看更多/);
      await page.screenshot({path:path.join(campaign,'results','exploration-country-'+code+'-'+width+'.png')});
      console.log('COUNTRY_TRANSLATION_OK',code,width);
      if (code==='zh') {
        await page.locator('#wlv-country-catalogue > summary').click();
        await page.locator('#co_catalogue_search').fill('巴西');
        await page.waitForFunction(() => document.querySelectorAll('.wlv-country-catalogue-link').length===1);
        assert.match(await page.locator('.wlv-country-catalogue-link').textContent(),/巴西/);
      }
      await navigate(page,'indicators');
      assert.match(await page.locator('label[for="indicators-search"]').textContent(), code==='es' ? /Buscar en el catálogo/ : /搜索目录/);
      await page.locator('[id^="indicators-catalogue_"]').first().click();
      await page.locator('#indicators-indicator_title').waitFor();
      await page.waitForFunction(() => document.querySelector('#indicators-indicator_title')?.textContent.trim());
      await page.waitForFunction(() => Object.keys(document.querySelector('#indicators-methods')?.selectize?.options || {}).length > 0);
      await page.locator('#indicators-methods').evaluate(node => node.selectize.setValue(Object.keys(node.selectize.options).filter(Boolean)));
      await page.waitForFunction(() => {
        const chart=document.querySelector('#indicators-series.js-plotly-plot, #indicators-series .js-plotly-plot');
        return chart?.data?.length>0 && (Shiny.shinyapp.$inputValues['indicators-methods'] || []).length>0;
      });
      await idle(page);
      assert.match(await page.locator('#indicators-export_label').textContent(), code==='es' ? /Descargar la serie/ : /下载所选序列/);
      await page.screenshot({path:path.join(campaign,'results','exploration-indicators-'+code+'-'+width+'.png')});
      console.log('INDICATOR_TRANSLATION_OK',code,width);
      if (width===1440) {
        const link=page.locator('[id^="indicators-workbook_"]').first();
        await link.waitFor();
        const downloading=page.waitForEvent('download');
        await link.click();
        const downloaded=await downloading;
        assert.equal(await downloaded.failure(),null);
        const output=path.join(campaign,'results','indicator-'+code+'.xlsx');
        await downloaded.saveAs(output);
        evidence.downloads.push({code,path:output,filename:downloaded.suggestedFilename()});
      }
      await navigate(page,'publications');
      assert.match(await page.locator('.form-group:has(#publications-author) label').textContent(), code==='es' ? /Miembro del proyecto/ : /项目成员/);
      await page.locator('.wlv-publication').first().waitFor();
      assert.ok(await page.locator('.wlv-publication').count()>0);
      assert.match(await page.locator('.wlv-publications-count').textContent(), code==='es' ? /referencias encontradas/ : /条文献记录/);
      await page.screenshot({path:path.join(campaign,'results','exploration-publications-'+code+'-'+width+'.png')});
      console.log('PUBLICATIONS_TRANSLATION_OK',code,width);
      const layout=await geometry(page);
      assert.ok(layout.scrollWidth<=width+2,JSON.stringify(layout));
      assert.ok(layout.contentScrollWidth<=layout.contentWidth+2,JSON.stringify(layout));
      assert.deepEqual(layout.errors,[]);
      evidence.views.push({code,...layout});
      await context.close();
    }
    assert.deepEqual(evidence.errors,[]);
    evidence.status='passed';
    console.log('EXPLORATION_TRANSLATIONS_BROWSER_OK');
  } finally {
    fs.writeFileSync(path.join(campaign,'results','exploration-translations.json'),JSON.stringify(evidence,null,2),'utf8');
    await browser.close();
  }
})().catch(error => {console.error(error);process.exitCode=1;});
