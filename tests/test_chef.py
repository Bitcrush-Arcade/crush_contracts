from brownie import accounts, GalacticChef, NICEToken, chain
from decimal import Decimal, getcontext
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
    getcontext().prec = 18

    return nice, token_1, token_2, token_3, chef


def test_add_pool(setup):
    _, token_1, _, _, chef = setup
    chef.addPool(
        token_1.address, 200000, 0, False, False, [], [], {"from": accounts[0]}
    )
    assert chef.poolCounter() == 1


def test_chain_halving(setup):
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
    assert Decimal.copy_abs(
        Decimal(twoChainEmission) - Decimal(oneChainEmission) / 2
    ) < Decimal(1000000)
    # A Third
    chef.editChains(True, {"from": accounts[0]})
    chain.sleep(2 * 60 * 60)
    twoChainEmission = chef.getCurrentEmissions(1)
    assert Decimal.copy_abs(
        Decimal(twoChainEmission) - Decimal(oneChainEmission) / 3
    ) < Decimal(1000000)
    # A fourth
    chef.editChains(True, {"from": accounts[0]})
    chain.sleep(2 * 60 * 60)
    twoChainEmission = chef.getCurrentEmissions(1)
    assert Decimal.copy_abs(
        Decimal(twoChainEmission) - Decimal(oneChainEmission) / 4
    ) < Decimal(1000000)


def test_non_defi_emissions(setup):
    nice, token_1, token_2, token_3, chef = setup
    chef.addPool(
        token_1, 200000, 0, False, False, [], [], {"from": accounts[0]}
    )  # pid 1
    chain.sleep(8 * 60 * 60)  # 8 hours, so 2 hours after deployment
    chef.editChains(True, {"from": accounts[0]})
    treasury = nice.balanceOf(accounts[1])
    p2e = nice.balanceOf(accounts[2])
    chefStart = chef.chefStart()
    nonDefiTime = chef.nonDefiLastRewardTransfer()
    difTime = nonDefiTime - chefStart
    # Emissions are halved ok
    expectedTreasury = Decimal(3.17097919837646000 * difTime)
    expectedP2E = Decimal(31.07559614408930000 * difTime)
    assert (
        Decimal.copy_abs(Web3.fromWei(treasury, "ether") - expectedTreasury) < 0.000001
    )
    assert Decimal.copy_abs(Web3.fromWei(p2e, "ether") - expectedP2E) < 0.000001


def test_pool_emissions(setup):
    nice, token_1, token_2, token_3, chef = setup
    chef.addPool(
        token_1, 500000, 0, False, False, [], [], {"from": accounts[0]}
    )  # pid 1
    chef.addPool(
        token_2, 300000, 0, False, False, [], [], {"from": accounts[0]}
    )  # pid 2
    chef.addPool(
        token_3, 200000, 0, False, False, [], [], {"from": accounts[0]}
    )  # pid 3

    token_1.mint(accounts[3], Web3.toWei(15000, "ether"), {"from": accounts[0]})
    token_1.mint(accounts[4], Web3.toWei(15000, "ether"), {"from": accounts[0]})
    token_2.mint(accounts[4], Web3.toWei(15000, "ether"), {"from": accounts[0]})
    token_3.mint(accounts[5], Web3.toWei(15000, "ether"), {"from": accounts[0]})

    token_1.approve(chef.address, Web3.toWei(100000, "ether"), {"from": accounts[3]})
    token_2.approve(chef.address, Web3.toWei(100000, "ether"), {"from": accounts[4]})
    token_3.approve(chef.address, Web3.toWei(100000, "ether"), {"from": accounts[5]})

    chef.deposit(Web3.toWei(100, "ether"), 1, {"from": accounts[3]})
    chef.deposit(Web3.toWei(100, "ether"), 2, {"from": accounts[4]})
    chef.deposit(Web3.toWei(100, "ether"), 3, {"from": accounts[5]})
    chain.sleep(8 * 60 * 60)  # 8 hours, so 2 hours after deployment

    chef.deposit(0, 1, {"from": accounts[3]})

    chef.deposit(0, 2, {"from": accounts[4]})
    chef.deposit(0, 3, {"from": accounts[5]})

    pool1Time = chef.poolInfo(1)[5] - chef.chefStart()
    pool2Time = chef.poolInfo(2)[5] - chef.chefStart()
    pool3Time = chef.poolInfo(3)[5] - chef.chefStart()

    received1 = nice.balanceOf(accounts[3])
    received2 = nice.balanceOf(accounts[4])
    received3 = nice.balanceOf(accounts[5])

    expected1 = (
        Decimal("13.318112633181100000")
        * Decimal(pool1Time)
        * Decimal(50)
        / Decimal(100)
    )
    expected2 = (
        Decimal("13.318112633181100000")
        * Decimal(pool2Time)
        * Decimal(30)
        / Decimal(100)
    )
    expected3 = (
        Decimal("13.318112633181100000")
        * Decimal(pool3Time)
        * Decimal(20)
        / Decimal(100)
    )

    assert Decimal(received1 / 10 ** 18) - expected1 < Decimal(0.000000001)
    assert Decimal(received2 / 10 ** 18) - expected2 < Decimal(0.000000001)
    assert Decimal(received3 / 10 ** 18) - expected3 < Decimal(0.000000001)

    chain.sleep(2 * 60 * 60)
    assert nice.balanceOf(accounts[4]) == 0
    token_1.approve(chef.address, Web3.toWei(10000, "ether"), {"from": accounts[4]})
    chef.deposit(Web3.toWei(100, "ether"), 1, {"from": accounts[4]})
    chain.mine(15)
    chain.sleep(2 * 60 * 60)
    expected1 = chef.pendingRewards(accounts[4], 1)
    chef.deposit(0, 1, {"from": accounts[4]})
    assert nice.balanceOf(accounts[4]) == expected1
