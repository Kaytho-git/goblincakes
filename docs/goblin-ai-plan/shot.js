const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 1.5 });
  await p.goto('file://' + __dirname + '/plan.html');
  await p.evaluate(() => document.fonts.ready);
  await p.screenshot({ path: __dirname + '/../goblin-ai-plan.png', fullPage: true });
  await b.close();
})();
