import config from './config.json';
export const FACTIONS = [
 {id:'horizon',name:'Horizon commun',short:'HC',color:'#8b7bff',motto:'Construire, ensemble.',description:'Le collectif et la coopération au cœur de la stratégie.',icon:'sun'},
 {id:'canopy',name:'Canopée',short:'CA',color:'#57d5a0',motto:'Enraciner le changement.',description:'Un mouvement fictif tourné vers les territoires et leur avenir.',icon:'leaf'},
 {id:'impulse',name:'Nouvel élan',short:'NE',color:'#ff987c',motto:'Faire bouger les lignes.',description:'Un mouvement fictif d’initiative et de mobilisation.',icon:'zap'},
 {id:'atlas',name:'Union Atlas',short:'UA',color:'#5aa9ff',motto:'Unir les territoires.',description:'La cohésion et la présence locale comme ligne de jeu.',icon:'shield'},
 {id:'aurora',name:'L’Aurore',short:'AU',color:'#e5be62',motto:'Un nouvel horizon.',description:'Un mouvement fictif fondé sur la participation et les idées.',icon:'sparkles'}
];
export type Action = keyof typeof config.actions;
export type Territory = {code:string;name:string;region:string;capital?:string;influence:Record<string,number>;defense:number;mobilization:number;bonus:string};
export type Player = {id?:string;username:string;faction:string;energy:number;budget:number;militants:number;influence:number;xp:number;campaigns:number;defenses:number;lastUpdate:number;lastAction:number;cards:Record<string,number>;claimed:string[];militantCarry:number;missionDay:string;daily:{campaigns:number;defenses:number}};
export type FeedItem={id:string;message:string;createdAt:number};
export type GameState = {rules?:typeof config;player:Player;territories:Territory[];events:FeedItem[];requests:string[];season:{id:string;name:string;start:number;end:number;phase:string;results?:{id:string;score:number}[];winner?:string;support?:string}};
export function faction(id:string){return FACTIONS.find(f=>f.id===id)||FACTIONS[0]}
export function dominant(t:Territory){return Object.entries(t.influence).sort((a,b)=>b[1]-a[1])[0]}
export function shares(t:Territory){const sum=Object.values(t.influence).reduce((a,b)=>a+b,0);return Object.fromEntries(Object.entries(t.influence).map(([id,v])=>[id,sum?100*v/sum:0]));}
export function territoryStatus(t:Territory){const values=Object.values(shares(t)).sort((a,b)=>b-a);return values[0]<config.controlThreshold?'Contesté':values[0]>=75?'Bastion':values[0]>=60?'Contrôle solide':'Contrôle fragile'}
export function createGame(meta:{code:string;name:string;region:string;capital?:string}[],now=Date.now()):GameState{
 return {player:{username:'Stratège',faction:'horizon',energy:100,budget:1600,militants:120,influence:250,xp:0,campaigns:0,defenses:0,lastUpdate:now,lastAction:0,cards:{'grand-meeting':3,bastion:2},claimed:[],militantCarry:0,missionDay:new Date(now).toISOString().slice(0,10),daily:{campaigns:0,defenses:0}},territories:meta.map((m,i)=>({...m,influence:Object.fromEntries(FACTIONS.map((f,j)=>[f.id,j===i%5?250+(i%3)*100:40+(i*7+j*13)%60])),defense:20+(i%5)*5,mobilization:15+(i%4)*5,bonus:i%7===0?'Place forte':'Mobilisation locale'})),events:[{id:'welcome',message:'Une nouvelle saison commence. La France est votre terrain de jeu.',createdAt:now}],requests:[],season:{id:'local-season',name:'La conquête',start:now-3*86400000,end:now+27*86400000,phase:'expansion'}};
}
export function regenerate(player:Player,now:number):Player{
 const elapsed=Math.max(0,now-player.lastUpdate);const ticks=Math.floor(elapsed/(config.energyMinutes*60000));
 return {...player,energy:Math.min(config.energyCap,player.energy+ticks),budget:Math.min(config.budgetCap,player.budget+ticks*Math.floor(config.budgetHourly*config.energyMinutes/60)),militants:Math.min(config.militantCap,player.militants+Math.floor((ticks*2+(player.militantCarry||0))/10)),militantCarry:(ticks*2+(player.militantCarry||0))%10,lastUpdate:ticks?player.lastUpdate+ticks*config.energyMinutes*60000:player.lastUpdate};
}
export function battleGain(investment:number,militants:number,defense:number,multiplier:number,random:number){
 const offense=(investment*config.offenseInfluence+militants*config.offenseMilitants)*multiplier*(1+(Math.max(0,Math.min(1,random))*2-1)*config.randomRange);
 return Math.max(1,Math.min(config.maxGain,Math.round((offense-defense*config.defenseCoefficient)*config.gainScale*10)));
}
export function campaign(state:GameState,input:{code:string;action:Action;investment:number;card?:string;requestId:string},now=Date.now(),random=Math.random()):GameState{
 if(state.requests.includes(input.requestId))return state;
 if(state.season.phase!=='expansion')throw new Error('La campagne de cette saison est terminée.');
 const p=regenerate(state.player,now),action=config.actions[input.action],t=state.territories.find(t=>t.code===input.code);
 if(!t||!action)throw new Error('Territoire ou action inconnu.');
 if(!Number.isInteger(input.investment)||input.investment<config.minInfluence||input.investment>config.maxInfluence)throw new Error('Investissement invalide.');
 if(now-p.lastAction<config.cooldownSeconds*1000)throw new Error('Attendez la fin du délai entre deux campagnes.');
 if(p.energy<action.energy||p.budget<action.budget||p.militants<action.militants||p.influence<input.investment)throw new Error('Ressources insuffisantes. Elles se régénèrent progressivement.');
 if(input.card&&(!(input.card in config.cards)||!p.cards[input.card]))throw new Error('Carte indisponible.');
 if(input.card==='bastion'&&input.action!=='defend')throw new Error('Bastion renforcé est une carte de défense.');
 if(input.card==='grand-meeting'&&input.action==='defend')throw new Error('Grand meeting est une carte de campagne.');
 const gain=battleGain(input.investment,action.militants,t.defense,action.multiplier*(input.card?config.cards[input.card as keyof typeof config.cards]:1),random);
 const nextT={...t,influence:{...t.influence,[p.faction]:(t.influence[p.faction]||0)+gain},defense:Math.min(100,t.defense+(input.action==='defend'?3:0))};
 const cards={...p.cards};if(input.card)cards[input.card]--;
 const day=new Date(now).toISOString().slice(0,10);const daily=p.missionDay===day?p.daily:{campaigns:0,defenses:0};
 const nextP={...p,missionDay:day,daily:{campaigns:daily.campaigns+1,defenses:daily.defenses+(input.action==='defend'?1:0)},energy:p.energy-action.energy,budget:p.budget-action.budget,militants:p.militants-action.militants,influence:p.influence-input.investment+Math.floor(gain/2),xp:p.xp+25,campaigns:p.campaigns+1,defenses:p.defenses+(input.action==='defend'?1:0),lastAction:now,cards};
 return {...state,player:nextP,territories:state.territories.map(t=>t.code===nextT.code?nextT:t),requests:[...state.requests.slice(-99),input.requestId],events:[{id:input.requestId,message:`${action.name} en ${t.name} : +${gain} points d’influence pour ${faction(p.faction).name}.`,createdAt:now},...state.events].slice(0,30)};
}
export function ranking(state:GameState){return FACTIONS.map(f=>({...f,score:state.territories.reduce((s,t)=>s+(shares(t)[f.id]||0),0)/Math.max(1,state.territories.length),territories:state.territories.filter(t=>dominant(t)[0]===f.id&&shares(t)[f.id]>config.controlThreshold).length})).sort((a,b)=>b.score-a.score)}
export function election(state:GameState):GameState{
 const scores=ranking(state).map(f=>({id:f.id,score:f.score}));
 if(state.season.phase==='finished')return state;
 if(state.season.phase==='expansion')return {...state,season:{...state.season,phase:'runoff',results:scores}};
 const finalists=(state.season.results||scores).slice(0,2).map(f=>({...f,score:f.score+(state.season.support===f.id?5:0)}));
 const total=finalists.reduce((s,f)=>s+f.score,0);const results=finalists.map(f=>({...f,score:100*f.score/total})).sort((a,b)=>b.score-a.score);
 return {...state,season:{...state.season,phase:'finished',results,winner:results[0].id}};
}
export function missionClaim(state:GameState,mission:'campaigns'|'defenses',now=Date.now()):GameState{
 const key=`${new Date(now).toISOString().slice(0,10)}:${mission}`;
 const day=new Date(now).toISOString().slice(0,10);const progress=state.player.missionDay!==day?0:mission==='campaigns'?state.player.daily.campaigns:state.player.daily.defenses;
 if(state.player.claimed.includes(key))throw new Error('Récompense déjà récupérée.');
 if(progress<(mission==='campaigns'?3:2))throw new Error('Mission incomplète.');
 return {...state,player:{...state.player,influence:state.player.influence+50,budget:Math.min(config.budgetCap,state.player.budget+200),xp:state.player.xp+50,cards:{...state.player.cards,[mission==='campaigns'?'grand-meeting':'bastion']:Math.min(20,(state.player.cards[mission==='campaigns'?'grand-meeting':'bastion']||0)+1)},claimed:[...state.player.claimed.slice(-19),key]}};
}
export {config};
