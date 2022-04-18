//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//BSC Address: 0x87F8e8f9616689808176d3a97a506c8cEeD32674

// openzeppelin
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// bitcrush
import "./NICEToken.sol";
import "./TestStaking2.sol";
import "./Presale.sol";

//import "../interfaces/IPresale.sol";
///@dev use interface IPresale

contract PresaleClaim is Ownable, ReentrancyGuard {
    NICEToken public niceToken;
    Presale public presale;
    PrevSale public prevsale;

    mapping(address => bool) public claimedTokens;
    event NiceClaimed(address indexed _buyer, uint256 _amount);

    constructor(
        address _nice,
        address _presale,
        address _prevsale
    ) {
        niceToken = NICEToken(_nice);
        presale = Presale(_presale);
        prevsale = PrevSale(_prevsale);
    }

    function claimTokens() public nonReentrant {
        require(!claimedTokens[msg.sender], "Already Claimed");
        claimedTokens[msg.sender] = true;
        uint256 owed;
        (, , uint256 prevOwed) = prevsale.userBought(msg.sender);
        (, , uint256 presaleOwed) = presale.userBought(msg.sender);
        owed = prevOwed + presaleOwed;
        require(owed > 0, "Didnt buy");
        niceToken.mint(msg.sender, owed);
        emit NiceClaimed(msg.sender, owed);
    }
}
