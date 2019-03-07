# Creating, issuing and storing credentials

This is a follow-on guide from `easy_get_started.md`.

Your prover and issuer actors should be onboarded and a secure channel should be set up between them - send a connection request from your issuer to prover.

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
    schema_name = schema['name']
    issuer['schema_id'], issuer[schema_name + '_schema'] = await anoncreds.issuer_create_schema(issuer['did'], schema_name, schema['version'], json.dumps(schema['attributes']))
    await send_schema(issuer['pool'], issuer['wallet'], issuer['did'], issuer[schema_name + '_schema'])
    ```
    Note that version numbers for schema must be floats, not ints.
    
2. Get the schema from the ledger, create a credential definition for your schema and register this.
    ```
    cred_def = {
        'tag': 'TAG1',
        'type': 'CL',
        'config': {
            "support_revocation": False # Use true here for revocation
        }
    }
    issuer['schema_id'], issuer[schema_name + '_schema'] = await get_schema(issuer['pool'], issuer['did'], schema_id)
    issuer[schema_name + '_cred_def_id'], issuer[schema_name + '_cred_def'] = await anoncreds.issuer_create_and_store_credential_def(issuer['wallet'], issuer['did'], issuer[schema_name + '_schema'], cred_def['tag'], cred_def['type'], json.dumps(cred_def['config']))
    await send_cred_def(issuer['pool'], issuer['wallet'], issuer['did'], issuer[schema_name + '_cred_def'])
    ```
    The credential is now ready to use.


## Issuing credentials

All communication as established in the `easy_getting_started.md` guide is encrypted and authenticated – see encryptions and decryptions below.

1. The issuer offers a credential to the prover.
    ```
    issuer[schema_name + '_cred_offer'] = await anoncreds.issuer_create_credential_offer(issuer['wallet'], issuer[schema_name + '_cred_def_id'])
    offer = {
        'name': schema_name,
        'cred_offer': issuer[schema_name + '_cred_offer']
    }
    issuer['prover_key_for_issuer'] = await did.key_for_did(issuer['pool'], issuer['wallet'], issuer['connection_response']['did']) # Use connection request DID if prover sent connection request to issuer
    authcrypted_cred_offer = await crypto.auth_crypt(issuer['wallet'], issuer['prover_key'], issuer['prover_key_for_issuer'], json.dumps(offer).encode('utf-8'))
    ```
    Send the authcrypted message bytes to the prover in your chosen manner.

2. The prover receives the credential offer and replies with a credential request.
    ```
    prover['issuer_key_for_prover'], _, json_cred_offer = await auth_decrypt(prover['wallet'], prover['issuer_key'], prover['authcrypted_cred_offer'])
    schema_name = json_cred_offer['name']
    prover[schema_name + '_cred_offer'] = json_cred_offer['cred_offer']
    authdecrypted_cred_offer = json.loads(json_cred_offer['cred_offer'])
    prover[schema_name + '_schema_id'] = authdecrypted_cred_offer['schema_id']
    prover[schema_name + '_cred_def_id'] = authdecrypted_cred_offer['cred_def_id']
    prover['master_secret_id'] = await anoncreds.prover_create_master_secret(prover['wallet'], None) # Allows prover to use credential
    prover['issuer_cred_def_id'], prover['issuer_cred_def'] = await get_cred_def(prover['pool'], prover['issuer_did'], authdecrypted_cred_offer['cred_def_id'])
    prover[schema_name + '_cred_request'], prover[schema_name + '_cred_request_metadata'] = await anoncreds.prover_create_credential_req(prover['wallet'], prover['issuer_did'], prover[schema_name + '_cred_offer'], prover['issuer_cred_def'], prover['master_secret_id'])
    cred_request = {
        'request': prover[schema_name + '_cred_request'],
        'values': {
            "first_name": {"raw": "Jason", "encoded": "1139481716457488690172217916278103335"},
            "last_name": {"raw": "Object", "encoded": "5321642780241790123587902456789123452"},
            "degree": {"raw": "Bachelor of Science, Data Structures", "encoded": "12434523576212321"},
            "status": {"raw": "graduated", "encoded": "2213454313412354"},
            "ssn": {"raw": "123-45-6789", "encoded": "3124141231422543541"},
            "year": {"raw": "2015", "encoded": "2015"},
            "average": {"raw": "5", "encoded": "5"}
        } # Encoding is arbitrary
    }
    authcrypted_cred_request = await crypto.auth_crypt(prover['wallet'], prover['issuer_key'], prover['issuer_key_for_prover'], json.dumps(cred_request).encode('utf-8'))
    ```
    Send the authcrypted message bytes to the issuer in your chosen manner.

3. The issuer receives the credential request, creates and sends the full credential.

4. The prover receives the credential and stores it in their wallet.
    
