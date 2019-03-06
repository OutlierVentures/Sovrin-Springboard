# Python consumer developer guide

This is a consumer Python developer guide for Linux and Mac. It requires Docker.

The Indy SDK works in an [async](https://docs.python.org/3/library/asyncio.html) envrionment. It is worth thinking about the tools you use before starting to ensure they can work in an async way, for example instead of Flask you would look to use [Quart](https://pgjones.gitlab.io/quart/).


## Seriously simple overview

DIDs are public keys on the ledger which point to private personal information on end devices.

In order to get a DID, you must be _onboarded_ to the Indy network by someone already on it, known as your _trust anchor_. This can be a _Steward_ if you know no existing onboarded contacts. The node network is divided into pools, and to begin you must connect to a node pool.

Any interactions you set up will be between a set of actors, often an _issuer_, _prover_, _verifier_ and in the case of a local testnet a _Steward_. Working locally, you could run these for example on different ports to simulate a networked interaction.

Python dictionaries are used for most data structures, including to represent node pool information, actors and connection data. Each actor has to dynamically keep track of lot of information, which is easily done using disctionary entries.

In order to interact with anyone in the context of credentials you must establish a pairwise secure channel with them.

## Setup

The remainder of this document details:
1. Node pool setup.
2. Getting an actor connected.
3. Establishing a secure channel between actors and onboarding new trust anchors.

For issuing and storing credentials, see `prover_issuer.md`.

For credential proof and verification, see `prover_verifier.md`.

SDK imports for the following:
```
from indy import pool, wallet, did, crypto
```

The following also uses three helper functions:
1. [get_genesis_tx_path()](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/utils.py)
2. [wallet_credentials()](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/getting_started.py)
3. [send_nym()](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/getting_started.py)

Import or copy these functions into your file.

### Node pool setup

If working locally, start a node pool:
```
docker build -f indy/ci/indy-pool.dockerfile -t indy_pool .
docker run -itd -p 9701-9708:9701-9708 indy_pool
```

To stop this pool at any time: `docker stop $(docker ps | grep oef-core-image | awk '{ print $1 }')`

Set up the pool data structure on each actor's machine:
```
pool_ = { 'name': [PICK_A_NAME] }
pool_['genesis_txn_path'] = get_pool_genesis_txn_path(pool_['name'])
pool_['config'] = json.dumps({"genesis_txn": str(pool_['genesis_txn_path'])})
await pool.set_protocol_version(2) # Set version number according to pool - 2 is current for local.
await pool.create_pool_ledger_config(pool_['name'], pool_['config'])
pool_['handle'] = await pool.open_pool_ledger(pool_['name'], None)
```

### Actor setup

Actors are instantiated from standard wallets. Pass in your wallet address and key as environment variables. For local testing these can be any string as long as addresses are unique.

```
actor = {
    'name': [PICK_A_NAME],
    'wallet_config': json.dumps({'id': [ADDRESS]}),
    'wallet_credentials': json.dumps({'key': [WALLET_KEY]}),
    'pool': pool_['handle'],
    'role': 'TRUST_ANCHOR'
}
await wallet.create_wallet(wallet_config("create", actor['wallet_config']), wallet_credentials("create", actor['wallet_credentials']))
actor['wallet'] = await wallet.open_wallet(wallet_config("open", actor['wallet_config']), wallet_credentials("open", actor['wallet_credentials']))
```

For pointers on nifty error handling you can take a look [here](https://github.com/hyperledger/indy-sdk/blob/master/samples/python/src/getting_started.py).

For local pools you will need to instantiate a _Steward_ actor from a seed. Just append this: 
```
actor['did_info'] = json.dumps({'seed': '000000000000000000000000Steward1'})
actor['did'], actor['key'] = await did.create_and_store_my_did(actor['wallet'], actor['did_info'])
```

The Steward can be used to onboard any other actors you have, which is simply the secure channel setup process with two extra steps.


### Secure channel setup

Indy secure channels are pairwise. You can at any time generate a new DID-keypair for each connection using:
```
did, key = await did.create_and_store_my_did(to['wallet'], "{}")
```

The following assumes you have a way to transmit data between agents, for example HTTP POSTing. Particularly sensitive data is pairwise encrypted on Hyperledger Indy but it is a good idea to use a secure scheme like HTTPS in addition.

1. Alice sends a connection request to Bov:
    ```
    alice['bob_did'], alice['bob_key'] = await did.create_and_store_my_did(alice['wallet'], "{}")
    await send_nym(alice['pool'], alice['wallet'], alice['did'], alice['alice_bob_did'], alice['alice_bob_key'], None)
    alice['connection_request'] = {
        'did': alice['alice_bob_did'],
        'nonce': [YOUR_FULLY_NUMERIC_NONCE]
    }
    ```
    Send the connection request dictionary to Bob in your chosen manner.

2. Bob receives the connection request and sends an anoncrypted connection response to Alice.
    ```
    bob['alice_did'], bob['alice_key'] = await did.create_and_store_my_did(bob['wallet'], "{}")
    bob['alice_bob_verkey'] = await did.key_for_did(pool_['handle'], bob['wallet'], connection_request['did']) # Use Alice's pool handle here to work cross-pool.
    bob['connection_response'] = json.dumps({
        'did': bob['alice_did'],
        'verkey': bob['alice_key'],
        'nonce': connection_request['nonce']
    })
    bob['anoncrypted_connection_response'] = await crypto.anon_crypt(bob['alice_bob_verkey'], bob['connection_response'].encode('utf-8'))
    ```
    Send the connection response bytes to Alice in your chosen manner.
    
3. Alice receives the connection response, storing Bob's verification key.
    ```
    alice['connection_response'] = json.loads((await crypto.anon_decrypt(alice['wallet'], alice['bob_key'], anoncrypted_connection_response)).decode("utf-8"))
    assert alice['connection_request']['nonce'] == alice['connection_response']['nonce'] # Check nonce is the one you sent!
    await send_nym(alice['pool'], alice['wallet'], alice['did'], alice['connection_response']['did'], alice['connection_response']['verkey'], None)
    ```

A secure channel has now been established. Any further messages from Bob to Alice can include the verkey and be encrypted using `crypto.auth_crypt()`. Alice can only decrypt the message with her key for Bob and can verify that Bob is the sender by comparing the received verkey to the verkey she gets from `await did.key_for_did(alice['pool'], alice['wallet'], alice['connection_response']['did'])`.

For a full Onboarding, e.g. using Steward Alice to onboard Bob, simply add two steps:

4. Bob generates his public DID (_Verinym_ or public key to be stored on the ledger) and sends this to Alice along with his verkey (as he will in all future messages to Alice).
    ```
    bob['did'], bob['key'] = await did.create_and_store_my_did(bob['wallet'], "{}")
    bob['did_info'] = json.dumps({
        'did': bob['did'],
        'verkey': bob['key']
    })
    bob['authcrypted_did_info'] = await crypto.auth_crypt(bob['wallet'], bob['alice_key'], bob['alice_bob_verkey'], bob['did_info'].encode('utf-8'))
    ```
    Send the authcrypted message bytes to Alice in your chosen manner.

5. Steward Alice receives the message, decrypts and registers Bob's DID on the ledger, establishing him as a new trust anchor.
    ```
    sender_verkey, _, authdecrypted_did_info = await auth_decrypt(alice['wallet'], alice['bob_key'], authcrypted_did_info)
    assert sender_verkey == await did.key_for_did(alice['pool'], alice['wallet'], alice['connection_response']['did'])
    await send_nym(alice['pool'], alice['wallet'], alice['did'], authdecrypted_did_info['did'], authdecrypted_did_info['verkey'], 'TRUST_ANCHOR') # Final parameter sets DID owner's role.
    ```
    From this point Bob is a trust anchor on the ledger and can onboard people in the same way that Alice can.


### Next steps

For issuing and storing credentials, see `prover_issuer.md`.

For credential proof and verification, see `prover_verifier.md`.

A first stop for technical questions is the [Indy-SDK rocket chat](https://chat.hyperledger.org/channel/indy-sdk).

