from brownie import (
    accounts,
    chain,
    NICEToken,
    FeeDistributorV3,
    interface,
    GalacticChef,
    TokenLock,
)
import pytest
from web3 import Web3

owner = accounts.load("my_user")
admin = accounts.load("bc_main")

# TEST WITH BSC-MAIN-FORK
@pytest.fixture
def setup():
    router = interface.IPancakeRouter("0x05E61E0cDcD2170a76F9568a110CEe3AFdD6c46f")
    crush = interface.IERC20("0x0ef0626736c2d484a792508e99949736d0af807e")
    nice = NICEToken.at("0x3a79410A3C758bF5f00216355545F4eD7CF0B34F")
    busd = interface.IERC20("0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56")
    bankroll = interface.IBitcrushBankroll("0xF43A7d04DcD76601dE0B0d03D761B09fBF095502")
    lottery = "0x9B55987e92958d3d6Af48Dd2DB1C577593401f78"
    chef = GalacticChef.deploy(
        nice,
        "0x79E441539a0760Eca6e08895E375F77AF2FBAa41",
        "0x3971A80119f789D548B4E78e89EFdb20f2C83Ff8",
        1,
        {"from": owner},
    )
    lock = TokenLock.deploy(chef.address, {"from": owner})
    fees = FeeDistributorV3.deploy(
        router,
        nice,
        crush,
        chef,
        lock,
        bankroll.address,
        owner.address,
        {"from": owner},
    )
    fees.editLottery(lottery, {"from": owner})
    bankroll.authorizeAddress(fees.address, {"from": admin})

    return (fees, owner, router, nice, crush, busd)


def test_final_distribution(setup):
    fees, owner, router, *_, busd = setup
    init_balance = owner.balance()
    fees.addorEditFee(
        1,
        [0, 0, 0],
        [2000, 500, 1500, 700, 1300],
        [True, False, False],
        router,
        [busd, router.WETH()],  # Token Composition in this case BUSD/BNB pair
        [],
        [],
        {"from": owner},
    )
    busd.transfer(fees.address, "100 ether", {"from": owner})
    fees.receiveFees(1, "100 ether", {"from": owner})

    assert busd.balanceOf(fees.address) == 0
    assert (owner.balance() - init_balance) / 10 ** 18 > 0.098


# def test_add_and_distribute_liquidity(setup):
#     fees, owner, router, _, crush, busd = setup
#     owner.transfer(fees, "0.000631516 ether")
#     crush.transfer(fees, "25 ether", {"from": owner})

#     pairToken = interface.INICEToken(
#         interface.IPancakeFactory(router.factory()).getPair(
#             crush.address, router.WETH()
#         )
#     )

#     fees.addAndDistributeLiquidity(
#         "25 ether", "0.000315758 ether", "0.000315758 ether", False
#     )

#     assert pairToken.balanceOf(fees.address) == 0


# def test_swap_tokens_for_eth(setup):
#     fees, owner, router, *_, busd = setup
#     fees.addorEditFee(
#         1,
#         [0, 0, 0],
#         [2000, 500, 1500, 700, 1300],
#         [True, False, False],
#         router,
#         [busd, router.WETH()],  # Token Composition in this case BUSD/BNB pair
#         [],
#         [],
#         {"from": owner},
#     )
#     busd.transfer(fees, "100 ether", {"from": owner})

#     fees.swapForEth(1, "100 ether", {"from": owner})
#     assert busd.balanceOf(fees) == 0
#     assert fees.balance() / (10 ** 18) > 0.24


# def test_swap_eth_for_tokens(setup):
#     fees, owner, _, nice, crush, _ = setup
#     user1 = accounts[0]
#     user1.transfer(fees, "1 ether")

#     fees.swapForToken("0.5 ether", False, {"from": owner})
#     niceBalance = nice.balanceOf(fees)
#     crushBalance = crush.balanceOf(fees)
#     assert niceBalance == 0
#     assert crushBalance > 0


# # This function will be commented afterwards since this is PURE and will be internal
# def test_add_arrays(setup):
#     fees, *_ = setup
#     amount = fees.addArrays([1, 2, 3], [4, 5, 6, 7, 8])

#     expected = 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8
#     assert amount == expected


# def test_update_paths(setup):
#     fees, owner, *_ = setup

#     fees.updatePaths(
#         1,
#         [accounts[1], accounts[2]],
#         [accounts[3], accounts[4], accounts[5]],
#         [accounts[6], accounts[7], accounts[8], accounts[9]],
#         {"from": owner},
#     )
#     paths = fees.getPath(1)
#     pathBase = paths[0]
#     path0Base = paths[1]
#     path1Base = paths[2]

#     assert len(pathBase) == 2
#     assert len(path0Base) == 3
#     assert len(path1Base) == 4


# # This function will be commented afterwards since this is PURE and will be internal
# def test_get_not_eth_token(setup):
#     fees, owner, router, *_, busd = setup
#     # ADD busd/Wbnb pair farm
#     fees.addorEditFee(
#         1,
#         [0, 0, 0],
#         [2000, 500, 1500, 700, 1300],
#         [False, False, False],
#         router,
#         [busd, router.WETH()],  # Token Composition in this case BUSD/BNB pair
#         [busd, router.WETH()],
#         [],
#         {"from": owner},
#     )

#     info = fees.getNotEthToken(1)
#     assert info["token"] == busd.address
#     assert len(info["path"]) == 2
#     assert info["path"][0] == busd.address
#     assert info["path"][1] == router.WETH()
#     assert info["hasFees"] == False


# def test_remove_liquidity_for_ETH_and_swap(setup):
#     fees, owner, router, nice, crush, busd = setup

#     # Add lP tokens...
#     factory = interface.IPancakeFactory(router.factory())
#     busdBnbPair = interface.IPancakePair("0x28f8ED3Bb8795b11e9be8A6015aDd73ef7Cd3a14")

#     busdBnbPair.transfer(fees, "0.45 ether", {"from": owner})
#     # SEND PAIR LP TOKEN TO FEES
#     # ADD busd/Wbnb pair farm
#     fees.addorEditFee(
#         1,
#         [0, 0, 0],
#         [2000, 500, 1500, 700, 1300],
#         [False, False, False],
#         router,
#         [busd, router.WETH()],  # Token Composition in this case BUSD/BNB pair
#         [busd, router.WETH()],
#         [],
#         {"from": owner},
#     )
#     # EXECUTE FN to swap for ETH
#     fees.removeLiquidityAndSwapETH(1, "0.45 ether", {"from": owner})

#     assert (
#         busdBnbPair.balanceOf(fees) < 100
#     )  # Value in ETH... get rid of all or most of the pair balance
#     assert busd.balanceOf(fees) < 100  # Get rid of all or most BUSD
#     assert (
#         fees.balance() > 42000000000000000
#     )  # 20BUSD and 20BUSD worth of BNB converted to BNB ~0.1BNB

#     ethBalance = fees.balance()

#     # swapETH for CRUSH
#     fees.swapForToken(ethBalance, False, {"from": owner})

#     assert fees.balance() < 10000  # Swap everything out... or almost everything
#     assert crush.balanceOf(fees) > 0  # Get any amount of crush we can
