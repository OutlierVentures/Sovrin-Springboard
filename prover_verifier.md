# Creating, issuing and storing credentials

This is a follow-on guide from `easy_get_started.md` and `prover_issuer.md.`

Your prover and verifier actors should be onboarded and a secure channel should be set up between them - send a connection request from your verifier to your prover. Your prover should have a credential stored in their wallet.

Imports:
```python
from indy import anoncreds, did, crypto
import json
```


## Requesting and verifying a credential proof

1. The verifier creates a proof request and sends it to the prover.
    ```python
    proof_request = json.dumps({
        "nonce": "0123456789012345678901234",
        "name": "Job-Application",
        "version": "0.1",
        "requested_attributes": {
            "attr1_referent": {
                "name": "first_name"
            },
            "attr2_referent": {
                "name": "last_name"
            },
            "attr3_referent": {
                "name": "degree"
            },
            "attr4_referent": {
                "name": "status"
            },
            "attr5_referent": {
                "name": "ssn"
            },
            "attr6_referent": {
                "name": "phone_number"
            }
        },
        "requested_predicates": {
            "predicate1_referent": {
                "name": "average",
                "p_type": ">=",
                "p_value": 4
            }
        }
    })
    prover_key_for_verifier = await did.key_for_did(verifier['pool'], verifier['wallet'], verifier['connection_response']['did'])
    authcrypted_proof_request = await crypto.auth_crypt(verifier['wallet'], verifier['prover_key'], prover_key_for_verifier, proof_request.encode('utf-8'))
    ```
    Send the authcrypted message bytes to the prover in your chosen manner.

2. The prover receives the proof request, constructs a proof and sends it back. In constructing a proof,
    1. The prover must specify which attributes are self-attested, which are to be verified with Indy, and which the credential issuer does not know about.
    ```python
    self_attested_attributes =
    {
        "attr1_referent": "Jason",
        "attr2_referent": "Object",
        "attr6_referent": "123-45-6789"
    }
    requested_attributes = [3, 4, 5]
    requested_predicates = [1],
    non_issuer_attributes = [6]
    ```
    2. The prover runs a search according to these specifications and gets the relvant entities from the ledger.
    ```python
    num_attributes_to_search = len(self_attested_attrs) + len(requested_attrs) - len(non_issuer_attributes) 
    num_predicates = len(requested_preds)
    prover['verifier_key_for_prover'], prover['proof_request'], _ = await auth_decrypt(prover['wallet'], prover['verifier_key'], prover['authcrypted_proof_request'])
    search_for_proof_request = await anoncreds.prover_search_credentials_for_proof_req(prover['wallet'], prover['proof_request'], None)
    cred_attrs = {}
    for i in range(1, num_attributes_to_search + 1):
        stri = str(i)
        cred_attrs['cred_for_attr' + stri] = await get_credential_for_referent(search_for_proof_request, 'attr' + stri + '_referent')
    cred_predicates = {}
    for i in range(1, num_predicates + 1):
        stri = str(i)
        cred_predicates['cred_for_predicate' + stri] = await get_credential_for_referent(search_for_proof_request, 'predicate' + stri + '_referent')
    await anoncreds.prover_close_credentials_search_for_proof_req(search_for_proof_request)
    creds_for_proof = {}
    for _, value in cred_attrs.items():
        creds_for_proof[value['referent']] = value
    for _, value in cred_predicates.items():
        creds_for_proof[value['referent']] = value
    prover['creds_for_proof'] = creds_for_proof
    prover['schemas'], prover['cred_defs'], prover['revoc_states'] = await prover_get_entities_from_ledger(prover['pool'], prover['verifier_did'], prover['creds_for_proof'], prover['name'])
    ```
    3. The prover constructs the full proof, composed of the self-attested attributes, requested attributes and requested predicates,
    ```python
    requested_attrs_dict = {}
    for i in requested_attrs:
        stri = str(i)
        requested_attrs_dict['attr' + stri + '_referent'] = {
            'cred_id': cred_attrs['cred_for_attr' + stri]['referent'], 'revealed': True
        } # Can specify what to reveal in plain (verifiable regardless)
    requested_predicates_dict = {}
    for i in requested_preds:
        stri = str(i)
        requested_predicates_dict['predicate' + stri + '_referent'] = {'cred_id': cred_predicates['cred_for_predicate' + stri]['referent']}
    proof_request_reply_from_prover = json.dumps({
        'self_attested_attributes': self_attested_attrs,
        'requested_attributes': requested_attrs_dict,
        'requested_predicates': requested_predicates_dict
    })
    proof = await anoncreds.prover_create_proof(prover['wallet'], prover['proof_request'], proof_request_reply_from_prover, prover['master_secret_id'], prover['schemas'], prover['cred_defs'], prover['revoc_states'])
    authcrypted_proof = await crypto.auth_crypt(prover['wallet'], prover['verifier_key'], prover['verifier_key_for_prover'], proof.encode('utf-8'))
    ```
    Send the authcrypted message bytes to the verifier in your chosen manner.

3. The verifier receives the proof and verifies it, specifying assertions to make about the credential.
    ```python
    _, proof, decrypted_proof = await auth_decrypt(verifier['wallet'], verifier['prover_key'], verifier['authcrypted_proof'])
    verifier['schemas'], verifier['cred_defs'], verifier['revoc_ref_defs'], verifier['revoc_regs'] = await verifier_get_entities_from_ledger(verifier['pool'], verifier['did'], decrypted_proof['identifiers'], verifier['name'])
    assertions_to_make = {
        "revealed": {
            "attr3_referent": "Bachelor of Science, Data Structures",
            "attr4_referent": "graduated",
            "attr5_referent": "123-45-6789"
        },
        "self_attested": {
            "attr1_referent": "Jason",
            "attr2_referent": "Object",
            "attr6_referent": "123-45-6789"
        } 
    }
    for key, value in assertions_to_make['revealed'].items():
        assert value == decrypted_proof['requested_proof']['revealed_attrs'][key]['raw']
    for key, value in assertions_to_make['self_attested'].items():
        assert value == decrypted_proof['requested_proof']['self_attested_attrs'][key]
    assert await anoncreds.verifier_verify_proof(verifier['proof_request'], proof, verifier['schemas'], verifier['cred_defs'], verifier['revoc_ref_defs'], verifier['revoc_regs'])
    ```
    The proof is now verified.


## Next steps

You now have the core tools you need for verifable credentials. You could start looking at [token payments](https://github.com/sovrin-foundation/libsovtoken).

A first stop for technical questions is the [Indy-SDK rocket chat](https://chat.hyperledger.org/channel/indy-sdk).
