from rdflib import Graph
from rdflib.query import Result
import requests
import plotly.graph_objects as go
from dash import dcc
from dash import html
from dash.dependencies import Input, Output
import dash
from SPARQLWrapper import SPARQLWrapper, JSON
import plotly.express as px
import geopandas as gpd
import numpy as np
import pandas as pd

jena_url = "http://127.0.0.1:3030/ds"

sparql = SPARQLWrapper(jena_url)

base_query = """ PREFIX : <http://127.0.0.1:3333/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>"""

query_date = base_query + """Select DISTINCT ?date WHERE { ?releve :annee_Emission ?date ;
    rdf:type "Mesure" . } Order by ASC(?date)"""
query_mileu = base_query + """Select DISTINCT ?milieu_pollution WHERE { ?releve rdf:type "Mesure" ;
    :milieu ?milieu_pollution . }"""

query_polluant = base_query + """Select DISTINCT ?lepolluant WHERE { ?releve rdf:type "Mesure" ;
    :polluant ?lepolluant . }
 """

query_unite = base_query + """SELECT DISTINCT ?lunite { ?releve rdf:type "Mesure" ;
    :unite ?lunite .
} """

query_test = base_query + """Select Distinct ?commune WHERE {
	?commune rdf:type :region .
}"""

def execute_query(query, sparql):
    full_quer = base_query + query
    sparql.setQuery(full_quer)
    sparql.setReturnFormat(JSON)
    return sparql.query().convert()

# contour des régions
geojson_url = "https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements.geojson"
gdf = gpd.read_file(geojson_url)

result_date = execute_query(query_date, sparql)
List_date = [date['date']['value'] for date in result_date["results"]['bindings']]
result_unite = execute_query(query_unite, sparql)
List_unite = [unite['lunite']['value']  for unite in result_unite["results"]['bindings']]
result_milieu = execute_query(query_mileu, sparql)
List_milieu = [milieu['milieu_pollution']['value']  for milieu in result_milieu["results"]['bindings']]
result_polluant = execute_query(query_polluant, sparql)
List_polluant = [polluant['lepolluant']['value']  for polluant in result_polluant["results"]['bindings']]


app = dash.Dash(__name__)



fig = px.choropleth(
    gdf,
    geojson=gdf.__geo_interface__,
    locations="code",  # Correspondance des départements
    featureidkey="properties.code",  # Clé à utiliser pour lier les départements
    title="Carte des départements de la France"
)
fig.update_geos(fitbounds="locations", visible=False)
fig.update_layout(margin={"r": 0, "t": 40, "l": 0, "b": 0})

dropdown_date = dcc.Dropdown(
    id='dropdown_date',
    options = [{'label':date , 'value':date} for date in List_date],
    #options=[{'label':date['date']['value'], 'value': date['date']['value']} for date in result_date["results"]['bindings']],
    value=List_date[0],
    multi=False )

dropdown_polluant = dcc.Dropdown(
    id='dropdown_polluant',
    options = [{'label':polluant , 'value':polluant} for polluant in List_polluant],
    value=List_polluant[0],
    multi=False
)
dropdown_unite = dcc.Dropdown(
    id='dropdown_unite',
    options= [{'label':unite, 'value':unite} for unite in List_unite],
    value=List_unite[0],
    multi=False
)

dropdown_milieu = dcc.Dropdown(
    id='dropdown_milieu',
    options=[ {'label': milieu, 'value': milieu} for milieu in List_milieu],
    value=List_milieu[0],
    multi=False
)


app.layout = html.Div([
    dropdown_date,
    dropdown_polluant,
    dropdown_unite,
    dropdown_milieu,
    dcc.Graph(
        id='map_fig',
        figure=fig
    )
])
@app.callback(
    dash.dependencies.Output('dropdown_polluant', 'options'),
    dash.dependencies.Input('dropdown_milieu', 'value')
)
def update_dropdown(milieu):
    query_polluant_with_milieur = """ Select Distinct ?lpolluant WHERE{
        ?releve rdf:type "Mesure" ;
            :milieu \""""+milieu+"""\" ;
            :polluant ?lpolluant .
    }"""
    result_polluant = execute_query(query_polluant_with_milieur, sparql)
    option = [{'label':polluant['lpolluant']['value'], 'value': polluant['lpolluant']['value']} for polluant in result_polluant['results']['bindings']]
    return option

@app.callback(
    dash.dependencies.Output('dropdown_unite', 'options'),
    [dash.dependencies.Input('dropdown_polluant', 'value')]
)

def update_dropdown_unite(polluant):
    query_unite_with_polluant = """ Select Distinct ?lunit WHERE{
        ?releve rdf:type "Mesure" ;
            :polluant \""""+polluant+"""\" ;
            :unite ?lunit .
    }"""
    result_unite = execute_query(query_unite_with_polluant, sparql)
    option = [{'label':unite['lunit']['value'], 'value': unite['lunit']['value']} for unite in result_unite['results']['bindings']]
    return option

@app.callback(
    dash.dependencies.Output('map_fig', 'figure'),
    [dash.dependencies.Input('dropdown_date', 'value'),
        dash.dependencies.Input('dropdown_milieu', 'value'),
        dash.dependencies.Input('dropdown_polluant', 'value'),
        dash.dependencies.Input('dropdown_unite', 'value')]
)
#qu'est ce qu'il faut que je fasse.

def update_map(annee, milieu, polluant, unite):
    result_by_departement = {}
    population_by_dep = {}
    query_update_graph = """ SELECT ?quantite ?num_departement ?population (YEAR(STRDT(?date, xsd:dateTime)) as ?year)  WHERE{
        ?releve rdf:type "Mesure" ;
            :milieu '"""+str(milieu)+"""' ;
            :polluant \""""+str(polluant)+"""\" ;
            :unite \""""+str(unite)+"""\" ;
            :quantite ?quantite ;
            :etablissement ?etablissement .
        ?etablissement :localiser ?commune .
        ?departement :possede ?commune ;
            :aPourCode ?num_departement ;
            :aPourPopulation [ :taille_population ?population ;
                                :date ?date ] .
            } order by ASC(?year) """
    result_update_graph = execute_query(query_update_graph, sparql)
    print("resultat pour le graph est ",result_update_graph)
    print("l'anne est ",annee)
    print("query : ", query_update_graph)
    for  mesure in result_update_graph["results"]["bindings"]:
        num_dep = mesure['num_departement']['value']
        quantite = mesure['quantite']['value']
        population=mesure['population']['value']
        if num_dep not in result_by_departement.keys():
            result_by_departement[num_dep]=[int(float(quantite))]
            population_by_dep[num_dep]=int(population)
        else:
            result_by_departement[num_dep].append(int(float(quantite)))
    df_mean_pollution = pd.DataFrame({'num_dep':[num_dep for num_dep in result_by_departement.keys()], 'pollution':[np.mean(poll_vals) for poll_vals in result_by_departement.values()]})
    df_pop = pd.DataFrame({'num_dep': list(population_by_dep.keys()), 'population':list(population_by_dep.values())})
    #options=[{'label':date['date']['value'], 'value': date['date']['value']} for date in result_date["results"]['bindings']],

    gdf_poll = gdf.merge(df_mean_pollution, left_on='code', right_on="num_dep", how="left")
    gdf_poll = gdf_poll.merge(df_pop, left_on='code', right_on="num_dep", how="left")

    # Remplir les valeurs NaN avec 0 (si un département n'a pas de pollution ou population enregistrée)
    gdf_poll.fillna(0, inplace=True)
    print(gdf_poll.columns)

    # Création de la carte
    fig = px.choropleth(
        gdf_poll,
        geojson=gdf.__geo_interface__,
        locations="code",  # Correspondance des départements
        featureidkey="properties.code",
        color="pollution",  # Couleur selon la pollution moyenne
        color_continuous_scale="Bluered",
        title="Carte de la Pollution Moyenne par Département"
    )

    # Ajouter des cercles proportionnels à la population
    fig.add_trace(
        go.Scattergeo(
            locations=gdf_poll['code'],
            hoverinfo="location+text",  # Afficher les informations de survol
            text=gdf_poll.apply(
                lambda row: f"Département: {row['nom']}<br>Pollution Moyenne: {row['pollution']:.1f} µg/m³<br>Population: {int(row['population']):,}", axis=1
            ),  # Affichage de la pollution et de la population
            mode='markers',
            marker=dict(
                size=gdf_poll['population'] / 100000,  # Ajuster la taille des cercles (éviter des cercles trop grands)
                color="red",  # Fixer la couleur des cercles
                opacity=0.7
            )
        )
    )
    fig.update_geos(fitbounds="locations", visible=False)
    fig.update_layout(margin={"r": 0, "t": 40, "l": 0, "b": 0})

    return fig
if __name__ =="__main__":
    app.run_server(debug=True, port=10910)
