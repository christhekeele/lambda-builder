from foo.bar import baz as library_function


def handler(event, context):

    # Proof that libraries are available
    library_function()

    # Echo event into JSON 'body' for API Gateway
    return {'body': json.dumps({'received': event})}
