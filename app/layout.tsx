import type {Metadata,Viewport} from 'next';
import './globals.css';
export const metadata:Metadata={title:'C’EST À QUI 2027 ? — La France est votre terrain de jeu',description:'Jeu gratuit de stratégie politique fictif. Construisez votre mouvement, conquérez les départements et remportez la présidentielle de la saison.',manifest:(process.env.NEXT_PUBLIC_BASE_PATH||'')+'/manifest.webmanifest',icons:{icon:(process.env.NEXT_PUBLIC_BASE_PATH||'')+'/icon.svg'}};
export const viewport:Viewport={themeColor:'#10111a',width:'device-width',initialScale:1};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="fr"><body>{children}</body></html>}
