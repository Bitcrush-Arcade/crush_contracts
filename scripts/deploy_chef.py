from imp import lock_held
from brownie import (
    GalacticChef,
    NICEToken,
    CRUSHToken,
    FeeDistributorV3,
    TokenLock,
    BitcrushNiceStaking,
    accounts,
    interface,
)


def main():
    owner = accounts.load("bc_main")
    # TOKENS
    nice = NICEToken.at("0x3a79410A3C758bF5f00216355545F4eD7CF0B34F")
    crush = CRUSHToken.at("0x0Ef0626736c2d484A792508e99949736D0AF807e")
    # wBnb = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
    # busd = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
    weth = "0x2170Ed0880ac9A755fd29B2688956BD959F933F8"
    wbtc = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c"
    # usdc = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d"
    # PAIRS
    nice_bnb = "0x7B83E9530775f8A940a93dFb745dC6c464aD34cf"
    nice_busd = "0x5491D8555C6FC3B9d5166D0e07A6eE01060B83e3"  # NEED THIS ADDRESS
    crush_bnb = "0x8A10489f1255fb63217Be4cc96B8F4CD4D42a469"
    crush_busd = "0x99B0dC3249e62b896c5ea592af29881131471519"
    busd_usdc = "0xC087C78AbaC4A0E900a327444193dBF9BA69058E"
    crush_nice = "0x493903279ad2463E5d73a1c95CCB33a63FDDf21A"
    busd_bnb = "0x51e6D27FA57373d8d4C256231241053a70Cb1d93"

    treasury = "0xf9C0f17D8C7714C4a384dB49B6893D8a00F17531"  # Treasury address
    p2e = "0x8f905B4bd5f028b250FF91fE70c1Fcb284E45f47"  # P2E Address
    marketing = "0x1b4Ec073BBC8A6F4bdC010918796b3721CF7F6e4"  # Team Wallet

    # bankroll = interface.IBitcrushBankroll("0xF43A7d04DcD76601dE0B0d03D761B09fBF095502")
    # router = interface.IPancakeRouter("0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7")
    # pancakeRouter = interface.IPancakeRouter(
    #     "0x10ED43C718714eb63d5aA57B78B54704E256024E"
    # )
    # DEPLOY CHEF
    chef = GalacticChef.deploy(nice, treasury, p2e, marketing, 1, {"from": owner})
    nice.toggleMinter(chef, {"from": owner})
    # Deploy Locker
    # lock = TokenLock.deploy(chef, {"from": owner})

    # DEPLOY FEE DISTRIBUTOR
    # distributor = FeeDistributorV3.deploy(
    #     router, nice, crush, chef, lock, bankroll, marketing, {"from": owner}
    # )
    distributor = FeeDistributorV3.at("0x45f194a1F2269904a181d6d29727aee4882B7995")

    # ADD FEE DISTRIBUTOR TO CHEF
    chef.editFeeAddress(distributor, True, {"from": owner})

    # ADD POOLS & it's fees
    # NICE BNB - APE 1
    mult1 = 35 * 10000  # -> 35X... this is the total so it would need to change
    chef.addPool(nice_bnb, mult1, 0, False, True, [], [], {"from": owner})
    # NICE BUSD - APE 2
    mult2 = 0 * 10000  # -> 15X... this is the total so it would need to change
    chef.addPool(nice_busd, mult2, 0, False, True, [], [], {"from": owner})
    # CRUSH BNB - APE 3
    mult3 = 0 * 10000  # -> 20X... this is the total so it would need to change
    chef.addPool(crush_bnb, mult3, 0, False, True, [], [], {"from": owner})
    # CRUSH BUSD- APE 4
    mult4 = 0 * 10000  # -> 5X... this is the total so it would need to change
    chef.addPool(crush_busd, mult4, 0, False, True, [], [], {"from": owner})
    # CRUSH NICE - APE 5
    mult5 = 0 * 10000  # -> 6X... this is the total so it would need to change
    chef.addPool(crush_nice, mult5, 0, False, True, [], [], {"from": owner})
    # BUSD USDC - APE 6
    mult6 = 0 * 10000  # -> 6X... this is the total so it would need to change
    chef.addPool(busd_usdc, mult6, 500, False, True, [], [], {"from": owner})
    # BUSD BNB - APE 7
    mult7 = 0 * 10000  # -> 6X... this is the total so it would need to change
    chef.addPool(busd_bnb, mult7, 500, False, True, [], [], {"from": owner})
    # NICE 8
    mult8 = 10 * 10000  # -> 5X... this is the total so it would need to change
    chef.addPool(nice, mult8, 0, False, False, [], [], {"from": owner})
    # ETH 9
    mult9 = 0 * 10000  # -> 1X... this is the total so it would need to change
    chef.addPool(weth, mult9, 500, False, False, [], [], {"from": owner})
    # BTC 10
    mult10 = 0 * 10000  # -> 1X... this is the total so it would need to change
    chef.addPool(wbtc, mult10, 500, False, False, [], [], {"from": owner})
    # CRUSH 11
    mult1X = 53 * 10000
    chef.addPool(crush, mult1X, 0, False, False, [], [], {"from": owner})
    chef.pausePool(11, True, {"from": owner})
    # NICE AUTOCOMPOUNDER
    niceCompounder = BitcrushNiceStaking.deploy(nice, {"from": owner})
    mult12 = 2 * 10000
    chef.addPool(niceCompounder, mult12, 0, True, False, [11], [0], {"from": owner})
    niceCompounder.setGalacticChef(chef, {"from": owner})
    niceCompounder.setPoolId(12, {"from": owner})
    niceCompounder.setStakingPool(
        "0x9D1Bc6843130fCAc8A609Bd9cb02Fb8A1E95630e", {"from": owner}
    )

    # # POOL6 BUSD-USDC
    # nice_burn = 0
    # nice_lq_perm = 4000
    # nice_lq_lock = 0
    # crush_burn = 0
    # crush_staker = 0
    # crush_lottery = 0
    # crush_lq_perm = 4000
    # crush_lq_lock = 0
    # distributor.addorEditFee(
    #     6,
    #     [nice_burn, nice_lq_perm, nice_lq_lock],
    #     [crush_burn, crush_staker, crush_lottery, crush_lq_perm, crush_lq_lock],
    #     [False, False, False],
    #     router,
    #     [busd, usdc],
    #     [busd, wBnb],
    #     [usdc, wBnb],
    #     {"from": owner},
    # )
    # # POOL7 BUSD BNB
    # nice_burn = 0
    # nice_lq_perm = 4000
    # nice_lq_lock = 0
    # crush_burn = 0
    # crush_staker = 0
    # crush_lottery = 0
    # crush_lq_perm = 4000
    # crush_lq_lock = 0
    # distributor.addorEditFee(
    #     7,
    #     [nice_burn, nice_lq_perm, nice_lq_lock],
    #     [crush_burn, crush_staker, crush_lottery, crush_lq_perm, crush_lq_lock],
    #     [False, False, False],
    #     router,
    #     [busd, wBnb],
    #     [busd, wBnb],
    #     [],
    #     {"from": owner},
    # )
    # # POOL 9 ETH
    # nice_burn = 0
    # nice_lq_perm = 0
    # nice_lq_lock = 0
    # crush_burn = 0
    # crush_staker = 0
    # crush_lottery = 0
    # crush_lq_perm = 6000
    # crush_lq_lock = 0
    # distributor.addorEditFee(
    #     9,
    #     [nice_burn, nice_lq_perm, nice_lq_lock],
    #     [crush_burn, crush_staker, crush_lottery, crush_lq_perm, crush_lq_lock],
    #     [False, False, False],
    #     router,
    #     [weth, wBnb],
    #     [],
    #     [],
    #     {"from": owner},
    # )
    # # POOL 10 BTC
    # nice_burn = 0
    # nice_lq_perm = 0
    # nice_lq_lock = 0
    # crush_burn = 0
    # crush_staker = 0
    # crush_lottery = 0
    # crush_lq_perm = 6000
    # crush_lq_lock = 0
    # distributor.addorEditFee(
    #     10,
    #     [nice_burn, nice_lq_perm, nice_lq_lock],
    #     [crush_burn, crush_staker, crush_lottery, crush_lq_perm, crush_lq_lock],
    #     [False, False, False],
    #     router,
    #     [wbtc, wBnb],
    #     [],
    #     [],
    #     {"from": owner},
    # )
