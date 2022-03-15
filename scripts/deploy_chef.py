from brownie import GalacticChef, FeeDistributor, accounts, NICEToken, TokenLock
from scripts.helpful_scripts import isDevNetwork


def deploy_lock(owner):
    return TokenLock.deploy({"from": owner})


def deploy_fee(owner, locker):
    # Receive Chef Address
    # Create Fees for PoolId
    pass


def deploy_chef(owner, token_address):
    if isDevNetwork():
        feeAddress = accounts[1]
    else:
        feeAddress = accounts.load("fee_address")  # get actual address where fees go to
    # Create Chef
    return GalacticChef.deploy(token_address, 20, 10, 1, {"from": owner})


def main():
    if isDevNetwork():
        owner = accounts[0]
    else:
        owner = accounts.load("main_owner")
    nice = NICEToken[-1]
    chef = deploy_chef(owner, nice.address)
    # MAKE CHEF BE A MINTER
    # Create new pool
    locker = deploy_lock(owner)

    pass
