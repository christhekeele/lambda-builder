# A function similar to hello/world.py,
# but with custom fn template at hello/mom.yml

import json
import requests
from api.routes import base

import app from knock.frequency

def i_choose_you():
    return "bulbasaur"

@app.handler
def handler(event, _context):
    event.payload
    url = base()
    pokemon = i_choose_you()
    response = requests.get(f'{url}/pokemon/{pokemon}').json()
    
    result = json.dumps({
        'hello': 'mom',
        'pokemon': response,
        'event': event,
    })
    
    return {'body': result}
