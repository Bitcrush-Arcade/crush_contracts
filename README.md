# Bitcrush Contracts

## Token Contract

CrushCoin Contract (CRUSH) is a simple BEP-20 token. 
* We've used `@pancakeswap/pancake-swap-lib` contracts as a base, because of this our contract is specified with `pragma solidity >= 0.6.2`.
* CRUSH has a maximum CAP of 30 million tokens minted.
* Burning tokens will reduce that maximum cap preventing more to be minted, keeping true to it's deflationary nature and preventing abuse by owners.
* Once DAO has a stable community, ownership of __*CRUSH will be transfered to DAO contract*__.
