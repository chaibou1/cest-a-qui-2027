import {createClient,type SupabaseClient} from '@supabase/supabase-js';
import {z} from 'zod';
import type {Action,GameState} from './game';
const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
export const configured=Boolean(url&&key);
let client:SupabaseClient|null=null;
export function db(){if(!configured)throw new Error('Le multijoueur attend la configuration Supabase. Le mode entraînement reste disponible.');return client??=createClient(url!,key!,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}})}
export function publicError(error:unknown){const message=error instanceof Error?error.message:typeof error==='object'&&error&&'message'in error?String(error.message):'Synchronisation indisponible. Réessayez avec le même identifiant d’action.';return /fetch|network/i.test(message)?'Connexion indisponible. Aucune action n’a été confirmée. Actualisez pour vérifier son statut.':message;}
export async function snapshot():Promise<{state:GameState;admin:boolean;rankings:{username:string;xp:number;faction:string}[]}>{const {data,error}=await db().rpc('game_snapshot');if(error)throw error;return data;}
export async function runCampaign(input:{code:string;action:Action;investment:number;card?:string;requestId:string}){
 const value=z.object({code:z.string().min(2).max(3),action:z.enum(['meeting','door','digital','defend']),investment:z.number().int().min(10).max(100),card:z.string().optional(),requestId:z.uuid()}).parse(input);
 const {data,error}=await db().rpc('play_campaign',{p_code:value.code,p_action:value.action,p_investment:value.investment,p_card:value.card||null,p_request_id:value.requestId});if(error)throw error;return data;
}
export async function rpc(name:string,args:Record<string,unknown>={}){const {data,error}=await db().rpc(name,args);if(error)throw error;return data;}
