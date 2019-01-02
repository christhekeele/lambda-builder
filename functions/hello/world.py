import os
import json # stdlib import
import requests # req import
from api.routes import base # lib import

# local function
def i_choose_you():
    return "pikachu"

# Required: lambda handler function
def handler(event, _context):

    # Demonstrate availability of:
    
    # Project 'lib' function: lib/api/routes.py:base()
    url = base()

    # Lambda-local function: functions/hello/world.py:i_choose_you()
    pokemon = i_choose_you()

    # Dependency function: requirements.txt:requests.get()
    response = requests.get(f'{url}/pokemon/{pokemon}').json()
    
    # Stdlib function: json.dumps()
    result = json.dumps({
        'hello': 'world',
        'foo:': os.environ.get('FOO'),
        'pokemon': response, # Echo request response
        'event': event, # Echo received event
    })

    # Return dict with JSON-encoded 'body'
    # for API Gateway to return a 200 response
    return {'body': result}
