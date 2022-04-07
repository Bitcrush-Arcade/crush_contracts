from brownie import MadInvaderNFT, accounts


def main():
    acct = accounts.load("cmos1")
    MadInvaderNFT.deploy(
        "Mad Nice Invaders",
        "MNI",
        "ipfs://Qmb9jvtyQFMXxx5Cd7XUkpAyfwGHwGaNLi376qAFyUwFvB/",
        "ipfs://QmQ5JMCG8wha57Lp4cBV7BgiDzxWE8xJMk9DoXCa5TrUtj/",
        "ipfs://QmNqMSj8ptnu6xJhwJr59vf7nF9oacr1h7mTPx3CjtLyGS/",
        {"from": acct},
    )
