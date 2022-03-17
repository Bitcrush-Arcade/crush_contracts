from brownie import accounts, NICEToken, IPancakeRouter, IPancakeFactory
import pytest
from scripts.deploy_chef import deploy_chef, deploy_fee, deploy_lock
from scripts.helpful_scripts import isDevNetwork


@pytest.fixture
def setup():
    owner = accounts[0]
    nice = NICEToken.deploy("NICE Token", "NICE", {"from": owner})
    test_Token1 = NICEToken.deploy("Test1", "TST1", {"from": owner})
    guard_token = NICEToken.deploy("Guard Token", "GUARD", {"from": owner})

    # router to use
    ape_router = IPancakeRouter.at("0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7")
    IPancakeFactory.at(ape_router.factory()).createPair()
    # CREATE PAIR FOR TEST TOKEN
    nice_pair = ape_router.createPair(nice, ape_router.WETH())
    test_pair = ape_router.createPair(test_Token1, ape_router.WETH())
    guard_pair = ape_router.createPair(guard_token, test_Token1)  # 3 step test

    # ADD PAIR LIQUIDITY

    chef = deploy_chef(owner, nice.address)
    # MAKE CHEF BE A MINTER
    nice.toggleMinter(chef.address)
    # Create new pool
    locker = deploy_lock(owner)
    # deploy fee distributor
    fee_distributor = deploy_fee(owner, chef, locker)

    return chef, locker, fee_distributor, nice


def test_addOrEditFee(chef, locker, feeDistributor, nice):

    # Setting up the fees
    # Establishing fees so that burn + distribute + lottery + permaliquidity + lockliquidity <= 10000
    pid = 0
    buyback_burn_fee = 500
    buyback_distribute_fee = 1000
    buyback_lottery_fee = 1500
    buyback_permaliquidity_fee = 2000
    buyback_lockliquidity_fee = 5000
    _bbNice = True
    _liqNice = True
    router = "0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7"


def test_receiveFees_test_pair(chef, locker, feeDistributor, nice):
    pass


def test_receiveFees_guard_pair(chef, locker, feeDistributor, nice):
    pass
