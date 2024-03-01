// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./DN404.sol";
import "./DN404Mirror.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

/*                               
_____/\\\\\\\\\\\____/\\\\____________/\\\\__/\\\_______/\\\__/\\\______________/\\\\\\\\\\\\\\\_        
 ___/\\\/////////\\\_\/\\\\\\________/\\\\\\_\///\\\___/\\\/__\/\\\_____________\/\\\///////////__       
  __\//\\\______\///__\/\\\//\\\____/\\\//\\\___\///\\\\\\/____\/\\\_____________\/\\\_____________      
   ___\////\\\_________\/\\\\///\\\/\\\/_\/\\\_____\//\\\\______\/\\\_____________\/\\\\\\\\\\\_____     
    ______\////\\\______\/\\\__\///\\\/___\/\\\______\/\\\\______\/\\\_____________\/\\\///////______    
     _________\////\\\___\/\\\____\///_____\/\\\______/\\\\\\_____\/\\\_____________\/\\\_____________   
      __/\\\______\//\\\__\/\\\_____________\/\\\____/\\\////\\\___\/\\\_____________\/\\\_____________  
       _\///\\\\\\\\\\\/___\/\\\_____________\/\\\__/\\\/___\///\\\_\/\\\\\\\\\\\\\\\_\/\\\\\\\\\\\\\\\_ 
        ___\///////////_____\///______________\///__\///_______\///__\///////////////__\///////////////__
*/

/// @title SMXLE

/*   BIG THANKS TO ========>
///  vectorized.eth (@optimizoor)
///  Quit (@0xQuit)
///  Michael Amadi (@AmadiMichaels)
///  cygaar (@0xCygaar)
///  Thomas (@0xjustadev)
///  Harrison (@PopPunkOnChain)
*/

contract SMXLE is DN404, Ownable {
    string private _name;
    string private _symbol;
    string public dataURI;
    string public baseTokenURI;
    bytes32 private _allowlistRoot;
    uint96 public publicPrice;
    uint96 public allowlistPrice; 
    uint32 public totalMinted; 
    bool public live;
    bool public isAllowListMint; // Allowlist mint state

    uint32 public constant MAX_PER_WALLET = 3;
    uint32 public constant MAX_SUPPLY = 4404;

    error InvalidProof();
    error InvalidMint();
    error InvalidPrice();
    error TotalSupplyReached();
    error NotLive();

    constructor(
        string memory name_,
        string memory symbol_,
        bytes32 allowlistRoot_,
        uint96 publicPrice_,
        uint96 allowlistPrice_,
        uint96 initialTokenSupply,
        address initialSupplyOwner
    ) {
        _initializeOwner(msg.sender);

        _name = name_;
        _symbol = symbol_;
        _allowlistRoot = allowlistRoot_;
        publicPrice = publicPrice_;
        allowlistPrice = allowlistPrice_;
        isAllowListMint = false; 

        address mirror = address(new DN404Mirror(msg.sender));
        _initializeDN404(initialTokenSupply, initialSupplyOwner, mirror);
    }

    modifier onlyLive() {
        if (!live) {
            revert NotLive();
        }
        _;
    }

    modifier checkPrice(uint256 price, uint256 nftAmount) {
        if (price * nftAmount != msg.value) {
            revert InvalidPrice();
        }
        _;
    }

    modifier checkAndUpdateTotalMinted(uint256 nftAmount) {
        uint256 newTotalMinted = uint256(totalMinted) + nftAmount;
        if (newTotalMinted > MAX_SUPPLY) {
            revert TotalSupplyReached();
        }
        totalMinted = uint32(newTotalMinted);
        _;
    }

    modifier checkAndUpdateBuyerMintCount(uint256 nftAmount) {
        uint256 currentMintCount = _getAux(msg.sender);
        uint256 newMintCount = currentMintCount + nftAmount;
        if (newMintCount > MAX_PER_WALLET) {
            revert InvalidMint();
        }
        _setAux(msg.sender, uint88(newMintCount));
        _;
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function mint(uint256 nftAmount)
    public
    payable
    onlyLive
    checkPrice(publicPrice, nftAmount)
    checkAndUpdateBuyerMintCount(nftAmount)
    checkAndUpdateTotalMinted(nftAmount)
    {
        if (!live) {
            revert NotLive();
    }

        if (isAllowListMint) {
            revert InvalidMint(); // Allowlist mint is active, cannot mint publicly
    }

         _mint(msg.sender, nftAmount * _unit());
    }

    function allowlistMint(uint256 nftAmount, bytes32[] calldata proof)
        public
        payable
        onlyLive
        checkPrice(allowlistPrice, nftAmount)
        checkAndUpdateBuyerMintCount(nftAmount)
        checkAndUpdateTotalMinted(nftAmount)
    {
        if (!live) {
            revert NotLive();
        }

        if (!isAllowListMint) {
            revert InvalidMint(); // Public mint is active, cannot mint via allowlist
        }

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProofLib.verifyCalldata(proof, _allowlistRoot, leaf)) {
            revert InvalidProof();
        }

        _mint(msg.sender, nftAmount * _unit());
    }


    function setPrices(uint96 publicPrice_, uint96 allowlistPrice_) public onlyOwner {
        publicPrice = publicPrice_;
        allowlistPrice = allowlistPrice_;
    }

    function toggleLive() public onlyOwner {
        live = !live;
    }
    function toggleWhitelistPhase() public onlyOwner {
        isAllowListMint = !isAllowListMint;
    }

    function withdraw() public onlyOwner {
        SafeTransferLib.safeTransferAllETH(msg.sender);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, LibString.toString(id));
        } else {
            uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(id))));
            string memory image;
            string memory color;

            if (seed <= 100) {
                image = "1.gif";
                color = "Green";
            } else if (seed <= 160) {
                image = "2.gif";
                color = "Blue";
            } else if (seed <= 210) {
                image = "3.gif";
                color = "White";
            } else if (seed <= 240) {
                image = "4.gif";
                color = "Yellow";
            } else if (seed <= 255) {
                image = "5.gif";
                color = "Red";
            }

            string memory jsonPreImage = string.concat(
                string.concat(
                    string.concat('{"name": "SMXLE #', LibString.toString(id)),
                    '","description":"4404 pieces of NFT 1,779,216 divisible tokens. First NFT mint attempt on DN404 contract.","external_url":"https://smxle.xyz","image":"'
                ),
                string.concat(dataURI, image)
            );
            string memory jsonPostImage = string.concat(
                '","attributes":[{"trait_type":"Color","value":"',
                color
            );
            string memory jsonPostTraits = '"}]}';

            return
                string.concat(
                    "data:application/json;utf8,",
                    string.concat(
                        string.concat(jsonPreImage, jsonPostImage),
                        jsonPostTraits
                    )
                );
        }
    }
}