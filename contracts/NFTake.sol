//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
// TODO audit
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract NFTake is Ownable, ERC721URIStorage {

    event BidPlaced(address indexed _from, uint256 indexed _id, uint256 _collateralAmount, uint256 _paymentAmount);
    // event BidPlaced(address indexed _from, uint256 indexed _id, uint256 _collateralAmount, uint256 _paymentAmount);
    // event BidPlaced(address indexed _from, uint256 indexed _id, uint256 _collateralAmount, uint256 _paymentAmount);
    // event BidPlaced(address indexed _from, uint256 indexed _id, uint256 _collateralAmount, uint256 _paymentAmount);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    IERC20 public immutable testDAI = IERC20(0xc3dbf84Abb494ce5199D5d4D815b10EC29529ff8);

    struct BorrowedAsset {
        uint256 fromTs;
        uint256 toTs;
        address borrower;
        // TODO debt asset (ERC20)
        uint256 debtAmount;
        // TODO same
        uint256 collateralAmount;
    }

    // User can have multiple borrows
    mapping (bytes32 => mapping (uint256 => BorrowedAsset)) borrowInfo;
    // Info for each token
    mapping (uint256 => AssetInternalStatus) tokenStatus;

    enum AssetInternalStatus {
        Free,
        Borrowed,
        BidPlaced,
        BorrowOutdated
    }

    struct Bid {
        address owner;
        uint256 collateralAmount;
        uint256 paymentAmount;
    }

    // tokenId => Bid / None
    mapping (uint256 => Bid) totalBids;
    // tokenId => status
    mapping (uint256 => AssetInternalStatus) assetStatus;
    
    // NOTE
    // X TODO make transfer to different domains
    // V TODO index by hash of domain name

    // TODO? modifier onlyContributor {
    //     // TODO Modifier for contributors (people who submit crypto-assets)
    // }

    // TODO what we need to setup?
    constructor() 
    ERC721("NFTake", "TKE") {
        // withdrawPeriod = _withdrawPeriod;
        console.log("Deploying a NFTake contract");
    }

    // Anyone can register NFT, and get into contributor's list
    function mintNFT(address recipient, string memory tokenURI)
        public 
        // onlyContributor
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        assetStatus[newItemId] = AssetInternalStatus.Free;
        return newItemId;
    }

    // Contributor can place his asset for sale, set (base approve amount), (full price) and more ?     
    function placeBid(uint256 tokenId, uint256 _collateralAmount, uint256 _paymentAmount) public {
        // TODO audit this call
        require(_isApprovedOrOwner(msg.sender, tokenId), "msg.sender not permitted to access this asset");
        // require token not already bidded or sold
        // require(totalBids[msg.sender][tokenId].basePrice == 0, "You already placed your bid!");
        // require(borrowInfo[msg.sender][tokenId].fromTs == 0, "This NFT was already borrowed!");
        require(assetStatus[tokenId] == AssetInternalStatus.Free, "This asset is already used / not initialized!");
        // TODO What else do we need?
        totalBids[tokenId] = Bid ({
                owner: msg.sender,
                collateralAmount: _collateralAmount,
                paymentAmount: _paymentAmount
        });
        assetStatus[tokenId] = AssetInternalStatus.BidPlaced;
        emit BidPlaced(msg.sender, tokenId, _collateralAmount, _paymentAmount); 
    } 

    function buyByTokenId(uint256 tokenId) public {
        require(assetStatus[tokenId] == AssetInternalStatus.BidPlaced, "NFT is not for sale!");
        // require(testDAI.)


        assetStatus[tokenId] == AssetInternalStatus.Borrowed;

    }
    function check_borrowed_asset(string memory domain, uint256 tokenId) 
    public view returns (AssetInternalStatus) {
        // TODO check if borrowskeccak(domain)
        // TODO this shall return something more useful)
        return assetStatus[tokenId];
    }

    // TODO later consider PoS or something?
    // function setWithdrawPeriod(uint256 _withdrawPeriod) public onlyOwner {
    //     // TODO require some boundaries
    //     withdrawPeriod = _withdrawPeriod;
    // }
}
