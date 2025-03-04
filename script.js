const $rdf = require("rdflib");
const endpoint = "http://127.0.0.1:3030/ds/query"; // Adresse correcte du serveur Fuseki
const query = `SELECT ?date WHERE { ?releve :Annee_Emission ?date }`;

const select = document.getElementById("date_drop");

// Chargement des données via RDFLib
const g = $rdf.graph();
const fetcher = $rdf.fetcher(g);

fetcher
  .webOperation(
    "GET",
    endpoint + "?query=" + encodeURIComponent(query) + "&format=json",
  )
  .then((response) => response.json())
  .then((data) => {
    console.log("Données reçues :", data);

    // Vérifier si les données sont valides et extraire les dates
    if (data.results && data.results.bindings.length > 0) {
      data.results.bindings.forEach((binding) => {
        const dateValue = binding.date.value; // Récupérer la valeur de la date

        // Créer une nouvelle option
        const option = document.createElement("option");
        option.value = dateValue;
        option.textContent = dateValue;
        select.appendChild(option);
      });
    } else {
      console.warn("Aucune donnée reçue.");
    }
  })
  .catch((error) =>
    console.error("Erreur lors de la récupération des données :", error),
  );
