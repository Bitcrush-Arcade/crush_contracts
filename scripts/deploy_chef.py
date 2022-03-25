from brownie import (
    GalacticChef,
    accounts,
    NICEToken,
    TokenLock,
    FeeDistributorV3,
    interface,
    BitcrushBankroll,
    BitcrushLottery,
    chain,
)
from scripts.helpful_scripts import isDevNetwork
from web3 import Web3


def deploy_fee_distributor(router, nice, crush, chef, lock, bankroll, marketing, owner):
    return FeeDistributorV3.deploy(
        router,
        nice,
        crush,
        chef,
        lock,
        bankroll,
        marketing,
        {"from": owner},
        publish_source=True,
    )


def deploy_chef(token, owner):
    return GalacticChef.deploy(
        token,
        "0xc528B36B9c7DB0DF961de167B84333C6cefF2A86",
        "0x3971A80119f789D548B4E78e89EFdb20f2C83Ff8",
        1,
        {"from": owner},
        publish_source=True,
    )


def deploy_token_locker(chef, owner):
    return TokenLock.deploy(chef, {"from": owner}, publish_source=True)


def main():
    owner = accounts.load("dev_deploy")
    user1 = accounts.load("my_user")
    # MAINNET
    # bankroll = BitcrushBankroll.at("0xF43A7d04DcD76601dE0B0d03D761B09fBF095502")
    # lottery = BitcrushLottery.at("0x9B55987e92958d3d6Af48Dd2DB1C577593401f78")
    # crush = interface.IERC20("0x0ef0626736c2d484a792508e99949736d0af807e")
    # nice = NICEToken.at("0x3a79410A3C758bF5f00216355545F4eD7CF0B34F")
    # TESTNET
    bankroll = BitcrushBankroll.at("0xb40287dA5A314F6AB864498355b1FCDe6703956D")
    lottery = BitcrushLottery.at("0x5979522D00Bd8D9921FcbDA10F1bfD5abD09417f")
    crush = interface.IERC20("0xa3ca5df2938126bae7c0df74d3132b5f72bda0b6")
    nice = NICEToken.at("0xAD026d8ae28bafa81030a76548efdE1EA796CB2C")
    # ROUTING AND LIQUIDITY
    router = interface.IPancakeRouter(
        # APESWAP ROUTER
        # "0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7"
        # PancakeSwap Router
        # "0x10ED43C718714eb63d5aA57B78B54704E256024E"
        # Pancake Testnet
        "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"
    )

    #  CHEF STUFF
    chef = deploy_chef(nice, owner)
    # Allow as minter
    nice.toggleMinter(chef.address, {"from": owner})
    # Token Locker (mainly will be Liquidity but can be used for a lot of things)
    locker = deploy_token_locker(chef, owner)
    # Deploy Fee Distributor
    fees = deploy_fee_distributor(
        router, nice, crush, chef, locker, bankroll, user1, owner
    )
    # Set Fee Address
    chef.editFeeAddress(fees, True, {"from": owner})

    # TESTING PHASE

    busd = interface.IERC20(
        # mainnet
        # "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
        # testnet
        "0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47"
    )
    # Add Fee Structure to Pool
    fees.addorEditFee(
        1,
        [0, 0, 0],
        [2000, 500, 1500, 700, 1300],
        [False, False, False],
        router,
        [busd, router.WETH()],
        [],
        [],
        {"from": owner},
    )
    # Create Pool A
    chef.addPool(busd, 20000, 500, False, False, [], [], {"from": owner})
