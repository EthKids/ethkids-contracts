# ethkids-contracts
This repo contains the contracts for the EthKids https://ethkids.io/ protocol.

The user interface is available in UI repo https://github.com/EthKids/ethkids-ui

#### How to add your NGO or charitable community
Landing on EthKids protocol takes just 15 minutes and some ETH to cover the deployment gas costs

Please let us know info.ethkids@gmail.com and we will guide you through  

#### How to do fresh deployment

In order to deploy to the network, two files in the root folder are required (not included in the repo):
- `.mnemonicTest` with the owner's mnemonic for deployment to the Rinkeby/Ropsten network
- `.mnemonicMain` registry's owner for Main net

After that
```
truffle migrate
```

Truffle migration script rolls over the CommunityRegistry, all dependent components and two donation communities.
