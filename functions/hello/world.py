import json # stdlib import
# req import
from foo.bar import baz # lib import


def handler(event, context):

    # Demonstrates libraries are available
    baz()

    # Echo event into JSON 'body' for API Gateway
    # Demonstrates stlib is available
    return {'body': json.dumps({'received': event})}
