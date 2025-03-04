from rdflib import Graph
import requests

ttl_file = "file_prelev.ttl"

g = Graph()

g.parse(ttl_file, format="turtle")

data = g.serialize(format="nt", encoding='utf-8')

jena_url = "http://127.0.0.1:3030/ds"

headers = {"content-type": "application/n-triples"}
response = requests.post(jena_url, data=data, headers=headers)
if response.status_code!=200:
	raise ValueError("une erreur c'est produite", response.status_code, " description: ", response.text)
