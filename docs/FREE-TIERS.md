# Services gratuits et sobriété

Documentation officielle consultée le **1 octobre 2026**. Les plafonds peuvent changer : consulter les liens avant chaque ouverture publique. Aucun numéro de carte bancaire ni service payant n’est nécessaire pour ce MVP.

| Service | Niveau retenu | Limites publiées / usage du MVP |
|---|---|---|
| [Supabase](https://supabase.com/pricing) | Free | 2 projets actifs, 500 Mo de base, 50 000 utilisateurs actifs mensuels, 5 Go de trafic sortant + 5 Go en cache, 1 Go de fichiers. Pause possible après une semaine d’inactivité. Aucun fichier utilisateur ni Realtime utilisé. |
| [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits) | Dépôt public, GitHub Free | Site publié ≤1 Go ; limite souple de 100 Go de trafic/mois ; 10 builds/heure ; durée maximum 10 minutes. Export Next.js statique ; les règles du jeu restent dans Supabase. |
| [GitHub](https://docs.github.com/en/get-started/learning-about-github/githubs-plans) | Free, dépôt public | Dépôt source et publication statique. Pas d’obligation d’abonnement. Les Actions ne sont pas nécessaires pour jouer ou publier une build locale. |

Le site n’utilise ni carte avec tuiles distantes, ni géocodage, ni API politique, ni IA, ni paiement, ni cron, ni serveur applicatif permanent. Le [fournisseur email intégré Supabase](https://supabase.com/docs/guides/auth/rate-limits) est limité à **2 emails par heure** selon la documentation consultée : configurer manuellement les comptes de test ou un Supabase local pendant le développement ; ne pas multiplier les tentatives d’inscription. L’envoi massif d’emails n’est pas une fonctionnalité du MVP. Pour ouvrir le jeu sans SMTP supplémentaire, désactiver « Confirm email » dans Auth pour ce MVP : l’adresse email reste non vérifiée, seul le mot de passe authentifie le compte. Ne pas la présenter comme une identité réelle certifiée. Le reset par email est hors MVP sans solution de délivrabilité gratuite configurée.

## Budget de requêtes

- Chargement carte et métadonnées : deux fichiers statiques en cache navigateur, une fois ; aucun téléchargement au clic sur un département.
- Multijoueur : un snapshot groupé à la connexion ou lors d’une actualisation manuelle. Un appel de campagne atomique, puis un snapshot. Aucun polling ni abonnement Realtime.
- Énergie, budget, militants : régénération calculée lors de la lecture/action ; aucun job ni écriture chaque seconde. Les reliquats de militants sont conservés.
- Campagne : cooldown configurable serveur, ressources vérifiées, inventaire plafonné à 20 exemplaires par carte, identifiant UUID conservé en cas d’échec réseau pour pouvoir rejouer la même requête sans double débit.
- Feed : 10 événements lus, 100 conservés ; classements : 25 joueurs ; campagnes : trois saisons conservées après un démarrage administratif ; résultats de saison archivés.
- La base est destinée à une petite communauté MVP. Aucun plafond d’utilisateurs illimité n’est promis. Surveiller le dashboard Supabase et suspendre les inscriptions avant saturation.

## Secours

- Pas de Supabase ou limite atteinte : erreur compréhensible ; aucune réussite affichée sans validation. L’entraînement local reste séparé du multijoueur.
- Réseau interrompu après une campagne : conserver le UUID et réessayer ou actualiser ; la procédure retourne le résultat déjà enregistré.
- Carte indisponible : sélecteur de départements utilisable ; aucun blocage de campagne.
- Hébergement indisponible : l’export `out/` peut être publié sur une autre offre gratuite statique. Recompiler `NEXT_PUBLIC_BASE_PATH` pour le nouvel hébergeur.
- Pause Supabase : réactiver manuellement depuis le dashboard. Ne pas contourner la pause avec un faux trafic automatique.
