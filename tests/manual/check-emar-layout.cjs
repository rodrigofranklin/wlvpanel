// Prova visual e de navegação da adaptação do e-mar, em navegador isolado.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP','TMP','TMPDIR']) {
  assert.equal(path.resolve(process.env[key] || ''), path.resolve(campaign, 'scratch'));
}
const results = path.join(campaign, 'results');
const evidence = [];
const widths = (process.env.WLV_BROWSER_WIDTHS || '1440,1024,768,390,320').split(',').map(Number);
const idle = page => page.waitForFunction(() => !document.documentElement.classList.contains('shiny-busy'));
async function checkIndicatorStyle(page, width) {
  const mobile = width < 768;
  if (mobile) {
    await page.locator('.wlv-map-indicator-toggle').click();
    await page.locator('.wlv-map-controls').waitFor({state:'visible'});
  }
  await page.locator('.wlv-map-group-body[data-expanded="true"]').evaluate(async node => {
    await Promise.all(node.getAnimations().map(animation => animation.finished));
  });
  const style = await page.evaluate(() => {
    const group = document.querySelector('.wlv-map-group-header[aria-expanded="true"]');
    const category = group.querySelector('span');
    const rows = [...group.parentElement.querySelectorAll('.wlv-map-indicator-row')];
    const selected = rows.find(row => row.querySelector('[aria-pressed="true"]'));
    const css = node => getComputedStyle(node);
    return {
      nav:css(document.querySelector('.navbar')).backgroundColor,
      sidebar:css(document.querySelector('.wlv-map-controls')).backgroundColor,
      category:{color:css(group).color,font:css(group).fontFamily,size:parseFloat(css(group).fontSize)},
      indicator:{font:css(rows[0]).fontFamily,size:parseFloat(css(rows[0]).fontSize)},
      menuSize:parseFloat(css(document.querySelector('#main_nav a')).fontSize),
      selected:{background:css(selected).backgroundColor,color:css(selected).color},
      markers:rows.map(row => {
        const marker = row.querySelector('.wlv-map-indicator-option').getBoundingClientRect();
        const label = row.querySelector('.wlv-map-indicator-label').getBoundingClientRect();
        return {categoryX:category.getBoundingClientRect().x,markerX:marker.x,
          markerRight:marker.right,labelX:label.x};
      })
    };
  });
  assert.equal(style.nav,'rgb(246, 174, 45)','Approved amber menu');
  assert.equal(style.sidebar,'rgb(141, 32, 40)','Approved dark red sidebar');
  assert.equal(style.category.color,'rgb(255, 162, 154)','Approved light red category');
  assert.deepEqual(style.selected,{background:'rgb(246, 174, 45)',color:'rgb(141, 32, 40)'});
  assert.ok(style.category.font.includes('Source Sans 3') && style.indicator.font.includes('Source Sans 3'));
  assert.equal(style.category.size,17);
  assert.equal(style.indicator.size,15);
  if (!mobile) assert.equal(style.menuSize,19.2);
  assert.ok(style.menuSize > style.category.size && style.category.size > style.indicator.size);
  for (const marker of style.markers) {
    assert.ok(Math.abs(marker.markerX-marker.categoryX)<1,
      'Left edge of selection marker aligns with category text: '+JSON.stringify(marker));
    assert.ok(marker.labelX>marker.markerRight,'Indicator text follows the marker on its right');
  }
  if (mobile) {
    await page.screenshot({path:path.join(results,'emar-indicators-'+width+'.png'),fullPage:true});
    await page.locator('.wlv-map-indicators-close').click();
    await page.locator('.wlv-map-controls').waitFor({state:'hidden'});
  }
  return style;
}
async function navigate(page, value) {
  const toggle = page.locator('.navbar-toggle');
  const mobile = await toggle.isVisible();
  if (mobile) {
    await page.waitForFunction(() => !document.querySelector('.navbar-collapse').classList.contains('collapsing'));
    if (!await page.locator('.navbar-collapse').evaluate(n=>n.classList.contains('in'))) await toggle.click();
    await page.waitForFunction(() => document.querySelector('.navbar-collapse').classList.contains('in'));
  }
  await page.locator('#main_nav a[data-value="'+value+'"]').click();
  await page.waitForFunction(value => Shiny.shinyapp.$inputValues.main_nav === value, value);
  if (mobile) await page.locator('.navbar-collapse').waitFor({state:'hidden'});
  await idle(page);
}
(async () => {
  const browser = await chromium.launch({headless:true});
  try {
    for (const width of widths) {
      const page = await browser.newPage({viewport:{width,height:900}});
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      try {
        await page.goto('http://127.0.0.1:'+(process.env.WLVPANEL_PORT || '38129'));
        await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav);
        await navigate(page,'map');
        await page.waitForFunction(() => window.WLVMap?.stats('map')?.layers > 0 &&
          document.querySelector('#map[aria-busy="false"]'));
        await idle(page);
        await page.evaluate(() => document.fonts.ready);
        const header = await page.evaluate(() => {
          const rect = selector => document.querySelector(selector).getBoundingClientRect().toJSON();
          const link = document.querySelector('#main_nav a');
          return {top:rect('.wlv-topbar'), nav:rect('.navbar'), logo:rect('.wlv-brand img'),
            language:rect('#language_toggle'), settings:rect('#settings_toggle'), menu:rect('#main_nav'),
            font:getComputedStyle(link).fontFamily, fontSize:getComputedStyle(link).fontSize,
            bodyWeight:getComputedStyle(document.body).fontWeight,
            fonts:document.fonts.check('600 19.2px "Source Sans 3"') &&
              document.fonts.check('400 15px "Source Sans 3"') &&
              [...document.fonts].some(face => face.family.replace(/["']/g,'') === 'Source Sans 3' &&
                face.status === 'loaded')};
        });
        assert.equal(header.top.height,45);
        assert.equal(header.logo.height,40);
        assert.ok(await page.locator('.wlv-brand img').evaluate(n=>n.complete&&n.naturalWidth>0),
          'Logo image is decoded by the browser');
        assert.equal(await page.locator('.wlv-brand img').getAttribute('src'),'a_batallar_ideas.png');
        assert.equal(header.nav.top,45);
        assert.equal(header.nav.bottom,100);
        assert.equal(header.top.width,width,'Header uses the entire viewport without a scrollbar gutter');
        assert.ok(header.fonts && header.font.includes('Source Sans 3'),
          'Source Sans 3 is applied and its font resource is loaded');
        assert.equal(header.bodyWeight,'400','Body text must not inherit the theme extra-light weight');
        assert.ok(header.logo.x < header.language.x && header.language.x < header.settings.x);
        assert.ok(Math.abs(header.top.right-header.settings.right-10)<1,
          'Language and settings are aligned with the right edge');
        if (width >= 1200) {
          assert.equal(header.fontSize,'19.2px');
          assert.ok(Math.abs(header.menu.x+header.menu.width/2-header.nav.width/2) < 1);
          const target = page.locator('#main_nav a[data-value="about"]');
          await target.hover();
          await page.waitForFunction(() => getComputedStyle(
            document.querySelector('#main_nav a[data-value="about"]'),'::after').left === '0px');
          const underline = await target.evaluate(n => {
            const style=getComputedStyle(n,'::after');
            return {height:style.height,transition:style.transitionDuration};
          });
          assert.equal(underline.height,'3px');
          assert.ok(underline.transition.includes('0.3s'));
        }
        const indicatorStyle = await checkIndicatorStyle(page,width);
        await page.screenshot({path:path.join(results,'emar-layout-'+width+'.png'),fullPage:true});
        const menuPositions = () => page.locator('#main_nav a').evaluateAll(nodes=>nodes.map(n=>{
          const r=n.getBoundingClientRect(); return {x:r.x,width:r.width};
        }));
        const initialPositions = await menuPositions();
        for (const value of ['about','country','indicators','download','publications','map']) {
          await navigate(page,value);
          if (width >= 768) assert.deepEqual(await menuPositions(),initialPositions,
            'Menu positions stay fixed when navigating to '+value);
          const state = await page.evaluate(() => ({width:innerWidth,scroll:document.documentElement.scrollWidth,
            errors:[...document.querySelectorAll('.shiny-output-error')]
              .filter(n=>n.offsetWidth&&n.offsetHeight).map(n=>n.textContent)}));
          assert.ok(state.scroll<=state.width+1,value+': '+JSON.stringify(state));
          assert.deepEqual(state.errors,[]);
        }
        await page.locator('#language_toggle').click();
        await page.waitForFunction(() => document.documentElement.lang === 'en');
        await idle(page);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth+1),
          'English menu fits the viewport');
        const englishPositions = await menuPositions();
        for (const value of ['about','map']) {
          await navigate(page,value);
          if (width >= 768) assert.deepEqual(await menuPositions(),englishPositions,
            'English menu positions stay fixed when navigating to '+value);
        }
        assert.equal(await page.locator('#settings_toggle').getAttribute('aria-label'),'Settings');
        await page.locator('#settings_toggle').click();
        await page.locator('#bases + .selectize-control').waitFor({state:'visible'});
        const settings = await page.locator('.wlv-settings-panel').boundingBox();
        assert.ok(settings.x>=0 && settings.x+settings.width<=width+1);
        await page.keyboard.press('Escape');
        assert.equal(await page.locator('#wlv-settings').evaluate(n=>n.open),false);
        await page.screenshot({path:path.join(results,'emar-layout-'+width+'-en.png'),fullPage:true});
        assert.deepEqual(errors,[]);
        evidence.push({width,status:'passed',header,indicatorStyle,navigation:true,language:true,settings:true});
      } catch (error) {
        await page.screenshot({path:path.join(results,'emar-layout-failure-'+width+'.png'),fullPage:true});
        throw error;
      } finally { await page.close(); }
    }
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(results,'emar-layout.json'),JSON.stringify(evidence,null,2),'utf8');
  }
  console.log(JSON.stringify(evidence.map(({width,status})=>({width,status})),null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
