from brownie import accounts, GalacticChef, NICEToken, chain
from web3 import Web3
import pytest


@pytest.fixture
def setup():
    nice = NICEToken.deploy("Nice", "NICE", {"from": accounts[0]})
    # TOKENS FOR POOLS
    token_1 = NICEToken.deploy("Test1", "TEST1", {"from": accounts[0]})
    token_2 = NICEToken.deploy("Test1", "TEST1", {"from": accounts[0]})
    token_3 = NICEToken.deploy("Test1", "TEST1", {"from": accounts[0]})

    chef = GalacticChef.deploy(nice, accounts[1], accounts[2], 1, {"from": accounts[0]})

    nice.toggleMinter(chef.address, {"from": accounts[0]})

    return nice, token_1, token_2, token_3, chef


def test_add_pool(setup):
    _, token_1, _, _, chef = setup
    chef.addPool(
        token_1.address, 200000, 0, False, False, [], [], {"from": accounts[0]}
    )
    assert chef.poolCounter() == 1


def test_chain_split(setup):
    nice, token_1, token_2, token_3, chef = setup
    chef.addPool(
        token_1, 200000, 0, False, False, [], [], {"from": accounts[0]}
    )  # pid 1
    chain.sleep(8 * 60 * 60)  # 8 hours, so 2 hours after deployment
    oneChainEmission = chef.getCurrentEmissions(1)
    chef.editChains(True, {"from": accounts[0]})
    chain.sleep(2 * 60 * 60)
    twoChainEmission = chef.getCurrentEmissions(1)
    # Emissions are halved ok
    assert twoChainEmission == oneChainEmission / 2


def test_chain_split(setup):
    nice, token_1, token_2, token_3, chef = setup
    chef.addPool(
        token_1, 200000, 0, False, False, [], [], {"from": accounts[0]}
    )  # pid 1
    chain.sleep(8 * 60 * 60)  # 8 hours, so 2 hours after deployment
    oneChainEmission = chef.getCurrentEmissions(1)
    chef.editChains(True, {"from": accounts[0]})
    chain.sleep(2 * 60 * 60)
    twoChainEmission = chef.getCurrentEmissions(1)
    # Emissions are halved ok
    assert twoChainEmission == oneChainEmission / 2
