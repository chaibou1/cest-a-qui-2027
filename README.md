# C’EST À QUI 2027 ?

**Conquiers les territoires. Construis ton mouvement. Remporte l’Élysée.**

[Jouer à la version publiée](https://chaibou1.github.io/cest-a-qui-2027/) · [Code source](https://github.com/chaibou1/cest-a-qui-2027)

MVP de jeu gratuit de stratégie politique fictif, indépendant de PRONO EDGE. Next.js + TypeScript + Tailwind, carte SVG issue de GeoJSON local réel, Supabase Auth/PostgreSQL/RLS. Aucun service payant requis, aucune IA ou paiement intégré.

## Jouer

```sh
npm ci
cp .env.example .env.local
npm run dev
```

Ouvrir `http://localhost:3000`. Sans Supabase, le jeu fonctionne en **entraînement local**, explicitement identifié et sauvegardé sur cet appareil. Ce mode n’est pas du multijoueur et ses résultats ne sont jamais publiés au classement serveur. Il permet de tester factions, carte, campagnes, ressources, cartes, missions et les deux tours fictifs. L’accélération des tours est réservée à l’entraînement.

## Activer le multijoueur

1. Créer un projet **Supabase Free dédié**, séparé de PRONO EDGE.
2. Exécuter [la migration complète](supabase/migrations/001_game.sql) **une fois** dans SQL Editor. Elle crée les tables, les factions/géographie, les profils automatiques, RLS et les procédures transactionnelles.
3. Copier dans `.env.local` `NEXT_PUBLIC_SUPABASE_URL` et `NEXT_PUBLIC_SUPABASE_ANON_KEY` (clé publique `anon` ou `sb_publishable_…`). Aucune clé `service_role` n’est nécessaire.
4. Activer Auth email/mot de passe. Pour un MVP public sans fournisseur email externe, désactiver **Confirm email** : les comptes fonctionnent sans envoi d’email, mais les adresses ne sont pas vérifiées. Si vous gardez la confirmation, l’email intégré est soumis aux restrictions Supabase (2 emails/h et destinataires autorisés) ; une solution de délivrabilité gratuite doit être configurée avant d’ouvrir les inscriptions. Définir **Site URL** et redirect URLs `/jeu/` dans Supabase Auth URL Configuration. Utiliser un Supabase local ou les comptes de test créés dans le dashboard pendant le développement ; respecter les quotas d’emails intégrés.
5. Redémarrer le dev ou **recompiler** : les variables publiques sont injectées à la build statique.
6. Créer un compte, confirmer l’email si activé, choisir une faction et lancer une campagne. Le mode affiché doit être **Multijoueur**.

Administration : créer le compte puis exécuter dans SQL Editor :

```sql
insert into public.game_admins(user_id)
select id from auth.users where email = 'votre-adresse-admin@exemple.fr';
```

`/admin/` et **chaque procédure admin** vérifient ce rôle côté PostgreSQL. Aucun joueur ne peut s’ajouter à cette liste ni modifier directement ses ressources/XP.

## Architecture

- `lib/game.ts` : entraînement et calculs purs ; jamais autorité du multijoueur.
- `supabase/migrations/001_game.sql` : règles serveur, verrous transactionnels, cooldown, ressources, inventaire, idempotence, missions, saisons et résultat enregistré une fois.
- `lib/backend.ts` : Supabase public, validation Zod, appels RPC. Aucun secret privé ni runtime serveur payant.
- `components/FranceMap.tsx` : carte réelle locale, outre-mer en encarts, filtre régional, sélecteur de secours.
- `components/GameApp.tsx` : état-major responsive et écrans Auth, territoire, faction, deck, profil, missions, classement, saison et admin.

La config serveur `game_config` est incluse dans le snapshot. Le client ne décide pas des gains multijoueur. UUID unique par joueur, débit atomique, réponse sauvegardée. Le même UUID est conservé en cas d’échec réseau. RLS et droits SQL empêchent l’écriture directe sur ressources/territoires. Le profil public contient uniquement des informations de jeu, aucun email ou mot de passe.

## Saison

Expansion de 30 jours ; après échéance, `advance_season` enregistre le premier tour. Deux finalistes, soutien unique des membres des factions éliminées, second tour après 48 h. Résultat sauvegardé, scores totalisant 100 %, égalités départagées de manière déterministe. Pas de cron. L’admin peut ouvrir le premier tour et démarrer une saison une fois la précédente terminée.

Les scores sont les moyennes des influences départementales **du jeu**, même poids par territoire. Bonus de soutien plafonné et identique pour les finalistes. Aucune simulation d’électorat réel.

## Vérifier

```sh
npm test
npm run check
npm run build
# Facultatif : Chromium local + serveur de out/ sur 3127
node scripts/smoke.mjs
```

Tests ciblés : coûts, progression, cartes, cooldown, régénération/reliquats, missions, idempotence, profil automatique, isolation ressources, refus d’auto-promotion/admin, deux tours stables. La migration s’exécute réellement dans PostgreSQL embarqué PGlite pour les tests. Ce dernier n’est pas la base multijoueur.

## Publier gratuitement

GitHub Pages, dépôt **public** GitHub Free :

```sh
NEXT_PUBLIC_BASE_PATH=/cest-a-qui-2027 npm run build
```

Publier `out/` dans `gh-pages`, ajouter `.nojekyll`, Settings → Pages → Deploy from branch → gh-pages / root. Le frontend est statique, les règles sont dans Supabase Free. Pour un hébergement à la racine (Cloudflare Pages, etc.), laisser `NEXT_PUBLIC_BASE_PATH` vide.

[Limites gratuites et secours](docs/FREE-TIERS.md) · [Géographie et licence](docs/GEOGRAPHY.md).

## Périmètre

MVP : 5 factions fictives, 101 départements, campagnes/défense, ressources, 2 cartes, missions quotidiennes, classements, feed borné, saison, deux tours fictifs, Auth et administration minimale.

Phase 2 : alliances, diplomatie, chat modéré, rôles avancés, bonus régionaux avancés. Phase 3 : personnalisation et tournois. Ces fonctionnalités ne sont pas présentées comme disponibles. Aucun candidat réel n’est présenté comme officiel.

> C’EST À QUI 2027 ? est un jeu de stratégie politique indépendant. Les scores, cartes, influences et résultats sont fictifs et ne constituent ni un sondage, ni une prévision électorale, ni une recommandation politique.
