// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MadInvaderNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string emperorURI;
    string othersURI;
    uint256 public maxEmperor = 100;
    uint256 public emperorSupply;
    uint256 public invaderSupply;

    string public baseExtension = ".json";

    uint256 public emperorCost = 0.4 ether;
    uint256 public invaderCost = 0.05 ether;
    uint256 public maxEmperors = 2;
    uint256 public maxInvaders = 5;

    uint256 public maxSupply = 8888;
    bool public paused = false;
    bool public revealed = false;
    string public notRevealedUri;
    mapping(address => bool) public whitelist;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initEmperorURI,
        string memory _initOthersURI,
        string memory _initNotRevealedUri
    ) ERC721(_name, _symbol) {
        setBaseURI(_initEmperorURI, true);
        setBaseURI(_initOthersURI, false);
        setNotRevealedURI(_initNotRevealedUri);
    }

    // internal
    function _baseURI(uint256 tokenId) internal view returns (string memory) {
        if (tokenId <= 100) return emperorURI;
        return othersURI;
    }

    // public
    function mint(uint256 _mintAmount, bool _type) public payable {
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "Zero");
        if (msg.sender != owner()) {
            uint256 maxMintAmount = _type ? 2 : 5;
            require(_mintAmount <= maxMintAmount, "MaxMint");
        }
        require(supply + _mintAmount <= maxSupply, "MaxSupply");
        uint256 cost = calculatePrice(_mintAmount, _type);
        if (_type) {
            require(emperorSupply + _mintAmount <= maxEmperor, "MaxEmperor");
            if (msg.sender != owner()) {
                require(!paused, "paused");
                if (whitelist[msg.sender]) {
                    whitelist[msg.sender] = false;
                    cost -= 0.01 ether;
                }
                require(msg.value >= cost, "Need to pay");
            }
            for (uint256 i = 1; i <= _mintAmount; i++) {
                _safeMint(msg.sender, emperorSupply + i);
            }
            emperorSupply += _mintAmount;
        } else {
            require(
                invaderSupply + _mintAmount <= maxSupply - maxEmperor,
                "MaxInvaders"
            );
            if (msg.sender != owner()) {
                require(msg.value >= cost * _mintAmount, "Need to pay");
                require(!paused, "paused");
            }

            for (uint256 i = 1; i <= _mintAmount; i++) {
                uint256 tokenId = invaderSupply + i + maxEmperor;
                _safeMint(msg.sender, tokenId);
            }
            invaderSupply += _mintAmount;
        }
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = _baseURI(tokenId);
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner
    function reveal() public onlyOwner {
        revealed = true;
    }

    function setCost(uint256 _newCost, bool _type) public onlyOwner {
        if (_type) emperorCost = _newCost;
        else invaderCost = _newCost;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function setBaseURI(string memory _newBaseURI, bool isEmperor)
        public
        onlyOwner
    {
        if (isEmperor) emperorURI = _newBaseURI;
        else othersURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function calculatePrice(uint256 _amount, bool _isEmperor)
        public
        view
        returns (uint256 _cost)
    {
        if (_isEmperor)
            _cost = _amount == 1 ? emperorCost : emperorCost - 0.1 ether;
        else _cost = _amount == 5 ? invaderCost - 0.01 ether : invaderCost;
    }

    function addWhitelisters(address[] calldata _users) external onlyOwner {
        uint256 length = _users.length;
        for (uint256 i = 0; i < length; i++) {
            whitelist[_users[i]] = true;
        }
    }

    function editMaxPerWallet(uint256 _newMax, bool _isEmperor)
        external
        onlyOwner
    {
        if (_isEmperor) maxEmperors = _newMax;
        else maxInvaders = _newMax;
    }
}
