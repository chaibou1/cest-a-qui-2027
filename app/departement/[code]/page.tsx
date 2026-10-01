import GameApp from '@/components/GameApp';
import metadata from '@/public/data/metadata.json';
export function generateStaticParams(){return metadata.map(d=>({code:d.code}))}
export default async function Page({params}:{params:Promise<{code:string}>}){const {code}=await params;return <GameApp view="carte" initialSelected={code}/>}
