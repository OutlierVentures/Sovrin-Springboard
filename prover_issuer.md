# Creating, issuing and storing credentials

This is a follow-on guide from `easy_get_started.md`.

Your prover and issuer actors should be onboarded and a secure channel should be set up between them.

Imports:
```
from indy import anoncreds, ledger, wallet, did, crypto
import json, time
```

The following assumes uses three helper functions:
1. [send_schema()](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/getting_started.py)
1. [get_schema()](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/getting_started.py)
2. [send_cred_def()](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/getting_started.py)

## Creating a credential

Credentials are created by the issuer.

1. Define a credential schema JSON and register it.
    ```
    schema = {
        "name": "Degree-Certificate",
        "version": "1.4",
        "attributes": ["first_name", "last_name", "degree"]
    }
    issuer['schema_id'], issuer[schema['name'] + '_schema'] = await anoncreds.issuer_create_schema(issuer['did'], schema['name'], schema['version'], json.dumps(schema['attributes']))
    await send_schema(issuer['pool'], issuer['wallet'], issuer['did'], issuer[schema['name'] + '_schema'])
    ```
    Note that version numbers for schema must be floats, not ints.
    
2. Get the schema from the ledger