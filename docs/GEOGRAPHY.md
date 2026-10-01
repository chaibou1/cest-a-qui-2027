# Géographie et attributions

`public/data/departments.geojson` contient les 101 départements : 96 métropolitains et 5 ultramarins. Les collectivités d’outre-mer ne sont pas des départements et ne sont pas incluses.

Source : [gregoiredavid/france-geojson, départements avec outre-mer](https://github.com/gregoiredavid/france-geojson/blob/master/departements-avec-outre-mer.geojson). Frontières issues de **IGN Admin Express COG 2018**, labels INSEE 2018, sous [Licence ouverte Etalab](https://www.etalab.gouv.fr/licence-ouverte-open-licence/), selon le [README de la source](https://github.com/gregoiredavid/france-geojson#licence). Téléchargé le 1 octobre 2026. Ce millésime est conservé explicitement ; ce n’est pas une promesse de frontière actualisée en temps réel.

Simplification supplémentaire avec Mapshaper, Visvalingam pondéré, conservation des formes, 10 %, précision 0,0001°. Fichier ramené d’environ 3,7 Mo à 366 Ko ; aucun tracé départemental n’est dessiné manuellement. D3 demande un ordre de coordonnées différent de GeoJSON RFC 7946 pour les polygones : leur orientation est adaptée uniquement dans le rendu SVG, sans modifier la source versionnée.

`public/data/metadata.json` : codes, noms et régions issus de [geo.api.gouv.fr](https://geo.api.gouv.fr/decoupage-administratif), téléchargement du 1 octobre 2026. Aucune requête géographique externe au runtime.

Les villes indiquées sur la carte sont des repères géographiques statiques. L’influence, les couleurs, les défenses, les bonus et les scores sont des **données fictives du jeu**. Aucun chiffre électoral réel ni population inventée n’est utilisé.
