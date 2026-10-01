import {chromium} from '@playwright/test';
import assert from 'node:assert/strict';
const base=process.env.TEST_URL||'http://127.0.0.1:3127';
const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const errors=[];
try{
 const page=await browser.newPage({viewport:{width:1440,height:1060}});
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto(base+'/jeu/');await page.locator('.france-svg path[role="button"]').first().waitFor();
 assert.equal(await page.locator('.france-svg path[role="button"]').count(),96);assert.equal(await page.locator('.overseas button').count(),5);
 await page.screenshot({path:'/tmp/cest-desktop.png',fullPage:true});
 await page.getByRole('button',{name:'Lancer la campagne'}).click();await page.getByText('Campagne terminée : votre influence progresse.').waitFor();
 assert.equal(await page.locator('.launch-button').isDisabled(),true);
 await page.goto(base+'/profil/');await page.getByRole('heading',{name:'Votre parcours de stratège.'}).waitFor();assert(await page.locator('.profile-stats').innerText().then(t=>t.includes('25')));
 await page.goto(base+'/presidentielle/');await page.getByRole('button',{name:'Simuler le premier tour'}).click();await page.getByRole('button',{name:'Simuler le second tour'}).click();await page.getByText('Président de la saison · Résultat fictif issu du jeu').waitFor();
 for(const route of ['accueil','factions','deck','missions','classement','saison','inscription','admin','departement/971']){const r=await page.goto(base+'/'+route+'/');assert.equal(r.status(),200);await page.locator('.page-heading h1').waitFor();}
 const mobile=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});mobile.on('pageerror',e=>errors.push(e.message));await mobile.goto(base+'/jeu/');await mobile.locator('.france-svg path[role="button"]').first().waitFor();
 await mobile.screenshot({path:'/tmp/cest-mobile.png',fullPage:true});
 assert.equal(await mobile.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 await mobile.locator('.france-svg path[aria-label^="Gironde,"]').click();await mobile.locator('.right-sidebar.mobile-open').waitFor();await mobile.getByRole('button',{name:'Lancer la campagne'}).click();await mobile.getByText('Campagne terminée : votre influence progresse.').waitFor();
 assert.deepEqual(errors,[]);console.log('Smoke OK: 101 départements, campagne, sauvegarde, présidentielle, 11 routes et mobile.');
}finally{await browser.close()}
