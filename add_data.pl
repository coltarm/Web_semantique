use strict;
use warnings;
use LWP::UserAgent;
use URI::Escape;
use JSON;
use RDF::Query::Client;
use Data::Dumper;
use HTTP::Request;
use Encode;

# Définition des préfixes SPARQL
my $prefix = <<'PREFIX';
PREFIX mfil: <http://127.0.0.1:3333/> 
PREFIX foaf: <http://xmlns.com/foaf/0.1/> 
PREFIX owl: <http://www.w3.org/2002/07/owl#> 
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
PREFIX vcard: <http://www.w3.org/2006/vcard/ns#> 
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
PREFIX dbo: <http://dbpedia.org/ontology/> 
PREFIX dbr: <http://dbpedia.org/resource/> 
PREFIX wd: <http://www.wikidata.org/entity/> 
PREFIX wdata: <http://www.wikidata.org/wiki/Special:EntityData/> 
PREFIX wdno: <http://www.wikidata.org/prop/novalue/> 
PREFIX wdref: <http://www.wikidata.org/reference/> 
PREFIX wds: <http://www.wikidata.org/entity/statement/> 
PREFIX wdt: <http://www.wikidata.org/prop/direct/> 
PREFIX wdtn: <http://www.wikidata.org/prop/direct-normalized/> 
PREFIX wdv: <http://www.wikidata.org/value/> 
PREFIX : <http://127.0.0.1:3333/> 
PREFIX

# Définition de l'endpoint Wikidata
my $endpoint = 'https://query.wikidata.org/sparql';
my $endpoint_my_rdf = 'http://127.0.0.1:3030/ds' ;

# Création du UserAgent avec timeout et User-Agent personnalisé
my $ua = LWP::UserAgent->new(timeout => 10);
$ua->agent("MyWikidataBot/1.0 (https://example.com/contact)");  # IMPORTANT pour éviter le blocage

=pode

# Définition de la requête SPARQL
my $sparql_query = <<'SPARQL';
SELECT ?label WHERE { 
  wd:Q42478 rdfs:label ?label . 
  FILTER (lang(?label) = "fr") 
}
SPARQL
# Concaténation des préfixes et de la requête
my $query = $prefix . "\n" . $sparql_query;

# Encodage de la requête pour utilisation dans l'URL
my $encoded_query = uri_escape($query);

# Construction de l'URL complète
my $url = "$endpoint?query=$encoded_query&format=json";

# Envoi de la requête
my $response = $ua->get($url);
if($response->is_success){
	print"ça fonctionne";
}
else {die "Erreur: " . $response->status_line;}
=cut

# get the commune and all the departement and counties
my $query_commune = << 'SPARQL';
Select Distinct ?code_commune WHERE {
	?commune rdf:type :Commune .
	?commune :codeInsee ?code_commune .
}
SPARQL
my $query_before_encode = $prefix . "\n" . $query_commune;
my $encoded_query_commune = uri_escape($query_before_encode);
my $url_comm = "$endpoint_my_rdf?query=$encoded_query_commune&format=json";
my $file_ttl = $prefix; 

#print "URL de la requête: $url_comm\n";
my $response_commune = $ua-> get($url_comm);

if ($response_commune->is_success) {
	#print("commune récupéré \n");
    my $content = $response_commune->decoded_content;
    my $data = decode_json($content);
    
    # Extraction et affichage des résultats
    foreach my $result (@{$data->{results}->{bindings}}) {
    	my $commune = $result->{code_commune}->{value};
	# get_departement
	my $query_dep = <<"SPARQL";
		SELECT DISTINCT ?departement ?departementLabel ?num_dep ?geoshape ?population  ?populationDate WHERE {		    
		?commune wdt:P374 '$commune' .
		?commune wdt:P131 ?departement . 
		?departement wdt:P31 wd:Q6465 ;
					wdt:P3896 ?geoshape ;
					wdt:P1082 ?population ;
					wdt:P2586 ?num_dep .

		OPTIONAL {
			?departement p:P1082 ?statement.
			?statement pq:P585 ?populationDate .
		}
		
		SERVICE wikibase:label { bd:serviceParam wikibase:language "fr" }
}

SPARQL
		my $query_dep_before = $prefix . "\n" . $query_dep;
		my $encode_query_dep = uri_escape($query_dep_before);
		my $url_dep = "$endpoint?query=$encode_query_dep&format=json";
		#print("$query_dep");
		#print "curl -X GET '$url_dep'\n";
		#print("$query_dep");
		my $response_dep = $ua->get($url_dep);
		sleep(0.5);

		if($response_dep->is_success){
			
			my $content_dep = $response_dep->decoded_content;
    		my $data_dep = decode_json($content_dep);

		foreach my $result_dep (@{$data_dep->{results}->{bindings}}) {
			my $departement = $result_dep->{departement}->{value};
			my $departement_label = encode('UTF-8',$result_dep->{departementLabel}->{value});
			my $population_dep = $result_dep->{population}->{value};
			my $date_population_dep = $result_dep->{populationDate}->{value};
			my $num_dep = $result_dep->{num_dep}->{value};
			my $geoshape_dep = $result_dep->{geoshape}->{value}; 
			my $query_update_departement = << "SPARQL";
			INSERT DATA{
				:departement_$num_dep rdf:type :Departement ;
					rdfs:label "$departement_label" ;
					:aPourPopulation [ :taille_population $population_dep ; 
										:date "$date_population_dep" ] ;
					:aPourGeoShape "$geoshape_dep" ;
					:possede :commune_$commune ;
					:aPourCode $num_dep .
			}			
SPARQL
			$file_ttl = $file_ttl . "\n" . $query_update_departement;
			my $req_dep = HTTP::Request->new(POST => $endpoint_my_rdf);
			$req_dep->header('Content-Type' => 'application/sparql-update');
			$req_dep->content($prefix . "\n" . $query_update_departement);
			my $res_dep = $ua->request($req_dep);
			if($res_dep->is_success){print("success add departement\n");}
			else {print(Dumper($req_dep));
			die "Erreur: " . $res_dep->status_line;}
=pod
			my $update_dep = RDF::Query::Client->new($prefix . "\n" . $query_update_departement);
			$update_dep->execute($endpoint_my_rdf, {UserAgent => $ua, QueryParameter=>"insert", QueryMethod =>"POST"});
=cut
			my $query_reg = <<"SPARQL";
				SELECT Distinct ?region ?regionLabel ?num_reg ?geoshape ?population ?date  WHERE {
					<$departement> wdt:P131 ?region .
					?region wdt:P31  wd:Q36784 ;
							wdt:P580 ?dateDebut ;  # Date officielle de création
							wdt:P3896 ?geoshape ;  # Forme géographique (GeoJSON)
							wdt:P1082 ?population ;  # Population totale
							wdt:P2585 ?num_reg .

					OPTIONAL {
						?region p:P1082 ?statement.
						?statement pq:P585 ?date.  # Date associée à la population
					}
					FILTER not Exists{?region wdt:P582 ?dateFin . }
					SERVICE wikibase:label { bd:serviceParam wikibase:language "fr" }
}
SPARQL
		

			my $encode_query_reg = uri_escape($prefix . "\n" . $query_reg);
			my $url_reg = "$endpoint?query=$encode_query_reg&format=json";
			my $response_reg = $ua->get($url_reg);
			sleep(0.5);

			if($response_reg->is_success){
				my $content_reg = $response_reg->decoded_content;
				my $data_reg = decode_json($content_reg);

			foreach my $result_reg(@{$data_reg->{results}->{bindings}}){
				
				my $num_reg = $result_reg->{num_reg}->{value};
				my $n_population_reg = $result_reg->{population}->{value};
				my $region_label = encode('UTF-8', $result_reg->{regionLabel}->{value});
				my $date_population_reg = $result_reg->{date}->{value};
				my $geoshape_reg = $result_reg->{geoshape}->{value};

				my $query_update_reg = << "SPARQL";
				INSERT DATA{
					:region_$num_reg rdfs:label \"$region_label\" ;
										rdfs:type :Region ;
										:aPourPopulation [
														:taille_population $n_population_reg ;
														:date \"$date_population_reg\" ] ;
										:aPourGeoShape \"$geoshape_reg\" ;
										:possede :departement_$num_dep .
				}
SPARQL
				
				$file_ttl = $file_ttl ."\n" .$query_update_reg; 
				my $req = HTTP::Request->new(POST => $endpoint_my_rdf);
				$req->header('Content-Type' => 'application/sparql-update');
				$req->content($prefix . "\n" . $query_update_reg);
				my $res = $ua->request($req);
				if($res->is_success){print("success add region\n");}
				else {print(Dumper($req));
					die "Erreur: " . $res->status_line;}

=pod
				my $update_reg = RDF::Query::Client->new($prefix . "\n" . $query_update_reg);
				$update_reg->execute($endpoint_my_rdf, {UserAgent => $ua, QueryParameter=>"update", QueryMethod =>"POST"}); 

				#print("region ajouter\n");
				my $query_test = "Select ?label WHERE {:region_$num_reg rdf:label ?label}";
				my $encode_query_test = uri_escape($prefix . "\n" . $query_test);
				my $url_test = "$endpoint_my_rdf?query=$encode_query_test&format=json";
				my $response_test = $ua->get($url_test);
				if($response_test->is_success){print("à réussi");}
				else {die "Erreur: " . $response_test->status_line;}
				#print("curl -X GET '$url_test' \n");
=cut 
			}
			} else {die "Erreur: " . $response_reg->status_line;}

			}
			} else {die "Erreur: " . $response_dep->status_line;}

    }

	open(my $fh, '>', 'supplement.ttl') or die "Impossible d'ouvrir le fichier: $!";
	print $fh $file_ttl;
	close($fh) or die "Impossible de fermer le fichier: $!";
} else {die "Erreur: " . $response_commune->status_line;}