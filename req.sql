#requête pour déterminer la population de une ville par date
SELECT ?item ?itemLabel ?population ?date
WHERE
{
	?item wdt:P374 "80021";
         wdt:P1082 ?population.
      OPTIONAL {
    ?item p:P1082 ?statement.
    ?statement pq:P585 ?date.  # Date associée à la population
    }
	SERVICE wikibase:label { bd:serviceParam wikibase:language "fr" }
}
Limit 100

Capital of : P1376
département de france: Q6465
official_name: P1448
geoshape : P3896
population : P1082

-- Je veux récupéré la population d'une commune ou d'une région" ou d'un département

get_departement : 
select ?dep Where{
	?item wdt:P374 "8021".
	?item wdt:P1376 ?dep.
	}
-- pour récupéré un département il faut soit se servir du label mais il peut y avoir des variations légéres du nom du département, aller chercher la régions

select ?departement Where{
	?item wdt:P374 "80021".
	?item wdt:P131 ?departement.
    ?departement wdt:P31 wd:Q6465. 
	}

recoupé les informations par année


xpath


Si on a pas les données dans la bdd on les reqûetes sur le net et on le mets dans la bdd.

Pour parcourir liste 

Select ?e where {
	:object :pop_list.
	? list rdf:rest=/rdf:forst ?e
}
