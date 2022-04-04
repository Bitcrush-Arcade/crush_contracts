from brownie import InvaderPool, accounts


def main():
    acct = accounts.load("cmos1")
    InvaderPool.deploy(
        "0xAD026d8ae28bafa81030a76548efdE1EA796CB2C",
        "0xed24fc36d5ee211ea25a80239fb8c4cfd80f12ee",
        "0xd1F88aF8c340CD31e013B5121b7300e992C7200A",
        11e18,
        18162515,
        100000e18,
        10000000e18,
        600,
        {"from": acct},
    )
